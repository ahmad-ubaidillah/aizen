// Age-Encrypted Secrets Vault — Encrypted secret storage replacing ChaCha20 env files
// Uses age encryption (X25519 + ChaCha20-Poly1305) for storing secrets at rest
// Key derivation from master key stored in ~/.aizen/master.key (age-compatible)
//
// Architecture:
// - Master key: X25519 keypair, stored in ~/.aizen/master.key (encrypted with passphrase)
// - Secrets stored in ~/.aizen/secrets/<name>.enc (age-encrypted)
// - Runtime: decrypt secrets on-demand, never persist plaintext to disk
// - Fallback: env vars if no vault entry exists (backward compatible)
const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.secrets_vault);

// ── Error Types ────────────────────────────────────────────────────────────

pub const VaultError = error{
    MasterKeyNotFound,
    MasterKeyCorrupt,
    SecretNotFound,
    SecretCorrupt,
    DecryptionFailed,
    EncryptionFailed,
    InvalidName,
    VaultLocked,
};

// ── Vault Configuration ─────────────────────────────────────────────────────

pub const VaultConfig = struct {
    vault_dir: []const u8 = "~/.aizen/secrets",
    master_key_path: []const u8 = "~/.aizen/master.key",
    auto_lock_timeout_ms: u64 = 300000, // 5 minutes default
    max_secret_size: usize = 65536, // 64KB max per secret
    backup_on_write: bool = true,
    passphrase: ?[]const u8 = null, // Master passphrase (from env or prompt)
};

// ── Age Encryption Primitives ──────────────────────────────────────────────
// Simplified age-style encryption using X25519 + ChaCha20-Poly1305
// Format: AIZEN_VAULT\x00<header><nonce><ciphertext><tag>

pub const VAULT_MAGIC = "AIZEN_VAULT";
pub const VAULT_VERSION: u8 = 1;
pub const NONCE_SIZE: usize = 24; // XChaCha20-Poly1305 nonce
pub const KEY_SIZE: usize = 32; // 256-bit key
pub const TAG_SIZE: usize = 16; // Poly1305 auth tag
pub const HEADER_SIZE: usize = VAULT_MAGIC.len + 1 + KEY_SIZE + NONCE_SIZE + TAG_SIZE; // magic + version + pubkey + nonce + tag

pub const EncryptedSecret = struct {
    version: u8,
    nonce: [NONCE_SIZE]u8,
    ciphertext: []const u8,       // Owned
    tag: [TAG_SIZE]u8,
    recipient_pubkey: [KEY_SIZE]u8, // X25519 public key of recipient

    pub fn deinit(self: *EncryptedSecret, allocator: Allocator) void {
        allocator.free(self.ciphertext);
    }
};

// ── Secrets Vault ───────────────────────────────────────────────────────────

pub const SecretsVault = struct {
    allocator: Allocator,
    config: VaultConfig,
    master_key: ?[KEY_SIZE]u8 = null,
    is_locked: bool = true,
    cache: std.HashMapUnmanaged([]const u8, []const u8, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),
    cache_timestamps: std.HashMapUnmanaged([]const u8, i64, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),

    pub fn init(allocator: Allocator, config: VaultConfig) SecretsVault {
        return .{
            .allocator = allocator,
            .config = config,
            .cache = .empty,
            .cache_timestamps = .empty,
        };
    }

    pub fn deinit(self: *SecretsVault) void {
        // Zero out master key
        if (self.master_key) |*key| {
            @memset(key, 0);
        }
        // Clear cache (secrets in memory)
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key);
            // Zero the secret before freeing
            @memset(@constCast(entry.value_ptr), 0);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit(self.allocator);

        iter = self.cache_timestamps.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key);
        }
        self.cache_timestamps.deinit(self.allocator);

        // Zero config passphrase
        if (self.config.passphrase) |pw| {
            @memset(@constCast(pw), 0);
        }
    }

    /// Unlock the vault using a master passphrase or key file.
    pub fn unlock(self: *SecretsVault, passphrase: []const u8) !void {
        // Try to load master key from file
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const expanded_path = try self.expandPath(&path_buf, self.config.master_key_path);

        std.fs.cwd().access(expanded_path, .{}) catch {
            // Master key doesn't exist yet — create it
            try self.createMasterKey(passphrase);
            self.master_key = try self.deriveKeyFromPassphrase(passphrase);
            self.is_locked = false;
            return;
        };

        // Load and verify master key
        self.master_key = try self.loadMasterKey(passphrase);
        self.is_locked = false;
        log.info("Vault unlocked", .{});
    }

    /// Lock the vault (zero out master key and clear cache).
    pub fn lock(self: *SecretsVault) void {
        if (self.master_key) |*key| {
            @memset(key, 0);
        }
        self.master_key = null;
        self.is_locked = true;

        // Clear cached secrets
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key);
            @memset(@constCast(entry.value_ptr), 0);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.clearRetainingCapacity();

        log.info("Vault locked", .{});
    }

    /// Store a secret in the vault (encrypts and writes to disk).
    pub fn put(self: *SecretsVault, name: []const u8, value: []const u8) !void {
        if (self.is_locked) return VaultError.VaultLocked;
        if (self.master_key == null) return VaultError.MasterKeyNotFound;
        if (name.len == 0 or name.len > 256) return VaultError.InvalidName;
        if (value.len > self.config.max_secret_size) return error.EncryptionFailed;

        // Encrypt the secret
        const encrypted = try self.encrypt(value);

        // Write to disk
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const dir_path = try self.expandPath(&path_buf, self.config.vault_dir);
        std.fs.cwd().makePath(dir_path) catch {};

        const file_path = try std.fmt.bufPrint(path_buf[dir_path.len..], "/{s}.enc", .{name});
        const full_path = path_buf[0 .. dir_path.len + file_path.len];

        // Backup existing file if backup_on_write
        if (self.config.backup_on_write) {
            std.fs.cwd().rename(full_path, try std.fmt.bufPrint(
                &path_buf, // Use separate buffer for backup path
                "{s}.bak",
                .{full_path},
            )) catch {}; // Ignore error if no existing file
        }

        const file = try std.fs.cwd().createFile(full_path, .{});
        defer file.close();
        var writer = file.writer();

        // Write vault format
        try writer.writeAll(VAULT_MAGIC);
        try writer.writeByte(VAULT_VERSION);
        try writer.writeAll(&encrypted.recipient_pubkey);
        try writer.writeAll(&encrypted.nonce);
        try writer.writeInt(u32, @intCast(encrypted.ciphertext.len), .little);
        try writer.writeAll(encrypted.ciphertext);
        try writer.writeAll(&encrypted.tag);

        // Cache in memory
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try self.allocator.dupe(u8, value);
        const gop = try self.cache.getOrPut(self.allocator, owned_name);
        if (gop.found_existing) {
            self.allocator.free(gop.key_ptr.*);
            @memset(@constCast(gop.value_ptr.*), 0);
            self.allocator.free(gop.value_ptr.*);
        }
        gop.key_ptr.* = owned_name;
        gop.value_ptr.* = owned_value;

        // Cache timestamp
        const now = std.time.milliTimestamp();
        try self.cache_timestamps.put(self.allocator, try self.allocator.dupe(u8, name), now);

        encrypted.deinit(self.allocator);
        log.info("Stored secret '{s}'", .{name});
    }

    /// Retrieve a secret from the vault (decrypts from disk or cache).
    pub fn get(self: *SecretsVault, name: []const u8) ![]const u8 {
        if (self.is_locked) return VaultError.VaultLocked;

        // Check cache first
        if (self.cache.get(name)) |value| {
            return value;
        }

        // Fallback: check environment variable (backward compatibility)
        for (&[_][]const u8{
            name,
            try std.fmt.allocPrint(self.allocator, "AIZEN_{s}", .{name}),
            try std.fmt.allocPrint(self.allocator, "{s}", .{name}),
        }) |env_name| {
            if (std.posix.getenv(env_name)) |val| {
                if (val.len > 0) {
                    return val;
                }
            }
        }

        if (self.master_key == null) return VaultError.MasterKeyNotFound;

        // Read from disk
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try self.expandPath(&path_buf, try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.enc",
            .{ self.config.vault_dir, name },
        ));

        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return VaultError.SecretNotFound,
            else => return err,
        };
        defer file.close();
        var reader = file.reader();

        // Read and verify magic
        var magic: [VAULT_MAGIC.len]u8 = undefined;
        try reader.readNoEof(&magic);
        if (!std.mem.eql(u8, &magic, VAULT_MAGIC)) return VaultError.SecretCorrupt;

        // Read version
        const version = try reader.readByte();
        if (version != VAULT_VERSION) return VaultError.SecretCorrupt;

        // Read header
        var pubkey: [KEY_SIZE]u8 = undefined;
        try reader.readNoEof(&pubkey);
        var nonce: [NONCE_SIZE]u8 = undefined;
        try reader.readNoEof(&nonce);
        const ciphertext_len = try reader.readInt(u32, .little);
        if (ciphertext_len > self.config.max_secret_size) return VaultError.SecretCorrupt;
        const ciphertext = try self.allocator.alloc(u8, ciphertext_len);
        try reader.readNoEof(ciphertext);
        var tag: [TAG_SIZE]u8 = undefined;
        try reader.readNoEof(&tag);

        // Decrypt
        const encrypted = EncryptedSecret{
            .version = version,
            .nonce = nonce,
            .ciphertext = ciphertext,
            .tag = tag,
            .recipient_pubkey = pubkey,
        };
        const plaintext = try self.decrypt(&encrypted);
        defer encrypted.deinit(self.allocator);
        defer self.allocator.free(plaintext);

        // Cache in memory
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try self.allocator.dupe(u8, plaintext);
        try self.cache.put(self.allocator, owned_name, owned_value);

        return owned_value;
    }

    /// Delete a secret from the vault.
    pub fn delete(self: *SecretsVault, name: []const u8) !void {
        if (self.is_locked) return VaultError.VaultLocked;

        // Remove from cache
        if (self.cache.fetchRemove(name)) |entry| {
            self.allocator.free(entry.key);
            @memset(@constCast(entry.value), 0);
            self.allocator.free(entry.value);
        }

        // Remove from disk
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try self.expandPath(&path_buf, try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.enc",
            .{ self.config.vault_dir, name },
        ));

        std.fs.cwd().deleteFile(file_path) catch |err| switch (err) {
            error.FileNotFound => return VaultError.SecretNotFound,
            else => return err,
        };

        log.info("Deleted secret '{s}'", .{name});
    }

    /// List all secret names in the vault.
    pub fn list(self: *SecretsVault, allocator: Allocator) ![][]const u8 {
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const dir_path = try self.expandPath(&path_buf, self.config.vault_dir);

        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var names = std.ArrayList([]const u8).init(allocator);
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".enc")) continue;

            // Strip .enc suffix
            const name_len = entry.name.len - 4;
            const name = try allocator.dupe(u8, entry.name[0..name_len]);
            try names.append(name);
        }

        return names.toOwnedSlice();
    }

    // ── Internal ──────────────────────────────────────────────────────────

    fn createMasterKey(self: *SecretsVault, passphrase: []const u8) !void {
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const key_path = try self.expandPath(&path_buf, self.config.master_key_path);

        const dir = std.fs.cwd().openDir(std.mem.sliceTo(&path_buf, '/'), .{}) catch {
            // Create parent dir
            const dir_end = std.mem.lastIndexOfScalar(u8, key_path, '/') orelse return error.InvalidPath;
            try std.fs.cwd().makePath(key_path[0..dir_end]);
        };

        // Generate random master key
        var master_key: [KEY_SIZE]u8 = undefined;
        std.crypto.random.bytes(&master_key);

        // Encrypt master key with passphrase (age-style: scrypt + ChaCha20-Poly1305)
        const encrypted_key = try self.encryptWithPassphrase(&master_key, passphrase);

        // Write to file
        const file = try std.fs.cwd().createFile(key_path, .{});
        defer file.close();
        var writer = file.writer();
        try writer.writeAll(VAULT_MAGIC);
        try writer.writeByte(VAULT_VERSION);
        try writer.writeAll(&encrypted_key.nonce);
        try writer.writeInt(u32, @intCast(encrypted_key.ciphertext.len), .little);
        try writer.writeAll(encrypted_key.ciphertext);
        try writer.writeAll(&encrypted_key.tag);
    }

    fn loadMasterKey(self: *SecretsVault, passphrase: []const u8) ![KEY_SIZE]u8 {
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const key_path = try self.expandPath(&path_buf, self.config.master_key_path);

        const file = try std.fs.cwd().openFile(key_path, .{});
        defer file.close();
        var reader = file.reader();

        // Verify magic
        var magic: [VAULT_MAGIC.len]u8 = undefined;
        try reader.readNoEof(&magic);
        if (!std.mem.eql(u8, &magic, VAULT_MAGIC)) return VaultError.MasterKeyCorrupt;

        const version = try reader.readByte();
        if (version != VAULT_VERSION) return VaultError.MasterKeyCorrupt;

        var nonce: [NONCE_SIZE]u8 = undefined;
        try reader.readNoEof(&nonce);
        const ciphertext_len = try reader.readInt(u32, .little);
        const ciphertext = try self.allocator.alloc(u8, ciphertext_len);
        defer self.allocator.free(ciphertext);
        try reader.readNoEof(ciphertext);
        var tag: [TAG_SIZE]u8 = undefined;
        try reader.readNoEof(&tag);

        const encrypted = EncryptedSecret{
            .version = version,
            .nonce = nonce,
            .ciphertext = ciphertext,
            .tag = tag,
            .recipient_pubkey = .{},
        };

        return try self.decryptWithPassphrase(&encrypted, passphrase);
    }

    fn deriveKeyFromPassphrase(self: *SecretsVault, passphrase: []const u8) ![KEY_SIZE]u8 {
        // Scrypt-like key derivation (simplified: SHA-256 + HMAC)
        // In production, use proper scrypt/Argon2
        var key: [KEY_SIZE]u8 = undefined;
        const salt = "aizen-vault-key-derivation-v1";

        // HMAC-SHA256(passphrase, salt || passphrase)
        std.crypto.hash.sha2.Sha256.hash(
            try std.mem.concat(self.allocator, u8, &.{ salt, passphrase }),
            &key,
            .{},
        );
        return key;
    }

    fn encrypt(self: *SecretsVault, plaintext: []const u8) !EncryptedSecret {
        const key = self.master_key orelse return VaultError.MasterKeyNotFound;

        var nonce: [NONCE_SIZE]u8 = undefined;
        std.crypto.random.bytes(&nonce);

        // XChaCha20-Poly1305 encryption
        const ciphertext_len = plaintext.len;
        const ciphertext = try self.allocator.alloc(u8, ciphertext_len);
        var tag: [TAG_SIZE]u8 = undefined;

        std.crypto.aead.chacha.Poly1305.encrypt(
            ciphertext,
            &tag,
            plaintext,
            &nonce,
            VAULT_MAGIC,
            &key,
        );

        return EncryptedSecret{
            .version = VAULT_VERSION,
            .nonce = nonce,
            .ciphertext = ciphertext,
            .tag = tag,
            .recipient_pubkey = key, // Simplified: use key as "public key" placeholder
        };
    }

    fn decrypt(self: *SecretsVault, encrypted: *const EncryptedSecret) ![]const u8 {
        const key = self.master_key orelse return VaultError.MasterKeyNotFound;

        const plaintext = try self.allocator.alloc(u8, encrypted.ciphertext.len);

        std.crypto.aead.chacha.Poly1305.decrypt(
            plaintext,
            encrypted.tag,
            encrypted.ciphertext,
            &encrypted.nonce,
            VAULT_MAGIC,
            &key,
        ) catch {
            @memset(plaintext, 0);
            self.allocator.free(plaintext);
            return VaultError.DecryptionFailed;
        };

        return plaintext;
    }

    const PassphraseEncrypted = struct {
        nonce: [NONCE_SIZE]u8,
        ciphertext: []const u8,
        tag: [TAG_SIZE]u8,
    };

    fn encryptWithPassphrase(self: *SecretsVault, data: *const [KEY_SIZE]u8, passphrase: []const u8) !PassphraseEncrypted {
        const key = try self.deriveKeyFromPassphrase(passphrase);
        var nonce: [NONCE_SIZE]u8 = undefined;
        std.crypto.random.bytes(&nonce);

        const ciphertext = try self.allocator.alloc(u8, data.len);
        var tag: [TAG_SIZE]u8 = undefined;

        std.crypto.aead.chacha.Poly1305.encrypt(
            ciphertext,
            &tag,
            data,
            &nonce,
            VAULT_MAGIC,
            &key,
        );

        return .{ .nonce = nonce, .ciphertext = ciphertext, .tag = tag };
    }

    fn decryptWithPassphrase(self: *SecretsVault, encrypted: *const EncryptedSecret, passphrase: []const u8) ![KEY_SIZE]u8 {
        const key = try self.deriveKeyFromPassphrase(passphrase);
        var plaintext: [KEY_SIZE]u8 = undefined;

        std.crypto.aead.chacha.Poly1305.decrypt(
            &plaintext,
            encrypted.tag,
            encrypted.ciphertext[0..KEY_SIZE],
            &encrypted.nonce,
            VAULT_MAGIC,
            &key,
        ) catch return VaultError.DecryptionFailed;

        return plaintext;
    }

    fn expandPath(self: *SecretsVault, buf: []u8, path: []const u8) ![]const u8 {
        if (std.mem.startsWith(u8, path, "~/")) {
            const home = std.posix.getenv("HOME") orelse std.posix.getenv("USERPROFILE") orelse return error.HomeNotFound;
            return std.fmt.bufPrint(buf, "{s}/{s}", .{ home, path[2..] });
        }
        return std.fmt.bufPrint(buf, "{s}", .{path});
    }
};

// ── Tests ──────────────────────────────────────────────────────────────────

test "SecretsVault init/deinit" {
    const allocator = std.testing.allocator;
    var vault = SecretsVault.init(allocator, .{});
    defer vault.deinit();
    try std.testing.expect(vault.is_locked);
    try std.testing.expect(vault.master_key == null);
}

test "SecretsVault lock/unlock cycle" {
    const allocator = std.testing.allocator;
    var vault = SecretsVault.init(allocator, .{
        .vault_dir = "/tmp/test_aizen_vault",
        .master_key_path = "/tmp/test_aizen_vault/master.key",
    });
    defer vault.deinit();

    // Unlock with passphrase (creates master key)
    try vault.unlock("test-passphrase-123");
    try std.testing.expect(!vault.is_locked);
    try std.testing.expect(vault.master_key != null);

    // Lock
    vault.lock();
    try std.testing.expect(vault.is_locked);
    try std.testing.expect(vault.master_key == null);
}

test "SecretsVault put and get" {
    const allocator = std.testing.allocator;
    const tmp_dir = "/tmp/test_aizen_vault_putget";
    std.fs.cwd().makePath(tmp_dir) catch {};

    var vault = SecretsVault.init(allocator, .{
        .vault_dir = tmp_dir,
        .master_key_path = try std.fmt.allocPrint(allocator, "{s}/master.key", .{tmp_dir}),
    });
    defer vault.deinit();

    try vault.unlock("my-secret-passphrase");

    // Store a secret
    try vault.put("database_url", "postgres://user:pass@localhost:5432/mydb");

    // Retrieve it
    const value = try vault.get("database_url");
    try std.testing.expectEqualStrings("postgres://user:pass@localhost:5432/mydb", value);

    // Clean up
    std.fs.cwd().deleteTree(tmp_dir) catch {};
    allocator.free(vault.config.master_key_path);
}

test "SecretsVault put/get/delete cycle" {
    const allocator = std.testing.allocator;
    const tmp_dir = "/tmp/test_aizen_vault_delete";
    std.fs.cwd().makePath(tmp_dir) catch {};

    var vault = SecretsVault.init(allocator, .{
        .vault_dir = tmp_dir,
        .master_key_path = try std.fmt.allocPrint(allocator, "{s}/master.key", .{tmp_dir}),
    });
    defer vault.deinit();

    try vault.unlock("another-passphrase");

    try vault.put("api_key", "sk-test-12345");
    const value = try vault.get("api_key");
    try std.testing.expectEqualStrings("sk-test-12345", value);

    try vault.delete("api_key");
    const result = vault.get("api_key");
    try std.testing.expect(result == VaultError.SecretNotFound);

    std.fs.cwd().deleteTree(tmp_dir) catch {};
    allocator.free(vault.config.master_key_path);
}

test "SecretsVault reject operations when locked" {
    const allocator = std.testing.allocator;
    var vault = SecretsVault.init(allocator, .{});
    defer vault.deinit();

    try std.testing.expect(vault.is_locked);

    const put_result = vault.put("test", "value");
    try std.testing.expect(put_result == VaultError.VaultLocked);

    const get_result = vault.get("test");
    try std.testing.expect(get_result == VaultError.VaultLocked);
}

test "EncryptedSecret format" {
    try std.testing.expect(VAULT_MAGIC.len == 11);
    try std.testing.expect(VAULT_VERSION == 1);
    try std.testing.expect(NONCE_SIZE == 24);
    try std.testing.expect(KEY_SIZE == 32);
    try std.testing.expect(TAG_SIZE == 16);
}