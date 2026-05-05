<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { api } from "$lib/api/client";

  type Step = "welcome" | "provider" | "validate" | "instance" | "finish";

  let currentStep = $state<Step>("welcome");
  let loading = $state(false);
  let error = $state("");

  // Provider state
  let providers = $state<any[]>([]);
  let selectedProvider = $state("");
  let apiKey = $state("");
  let baseUrl = $state("");
  let model = $state("");
  let models = $state<string[]>([]);
  let providerValidation = $state<any>(null);

  // Instance state
  let instanceName = $state("aizen-1");
  let creating = $state(false);
  let instanceResult = $state<any>(null);

  // Check first-time status
  let hasProviders = $state(false);
  let hasInstances = $state(false);
  let checking = $state(true);

  onMount(async () => {
    try {
      const [p, s] = await Promise.all([
        api.getSavedProviders(),
        api.getStatus(),
      ]);
      hasProviders = (p?.providers?.length ?? 0) > 0;
      hasInstances = Object.keys(s?.instances ?? {}).length > 0;
      if (hasProviders && hasInstances) {
        goto("/");
        return;
      }
    } catch (e) {
      error = (e as Error).message;
    } finally {
      checking = false;
    }
  });

  // Load provider list
  $effect(() => {
    if (currentStep === "provider") {
      loadProviders();
    }
  });

  async function loadProviders() {
    try {
      const data = await api.getSavedProviders();
      providers = data?.providers ?? [];
      if (providers.length > 0) {
        hasProviders = true;
        selectedProvider = providers[0].provider;
        apiKey = providers[0].api_key ?? "";
        baseUrl = providers[0].base_url ?? "";
        model = providers[0].model ?? "";
      }
    } catch (e) {
      error = (e as Error).message;
    }
  }

  async function fetchModels() {
    if (!selectedProvider || !apiKey) return;
    loading = true;
    error = "";
    try {
      const data = await api.getWizardModels("aizen", selectedProvider, apiKey);
      models = data?.models ?? [];
      if (models.length > 0 && !model) {
        model = models[0];
      }
    } catch (e) {
      error = (e as Error).message;
      models = [];
    } finally {
      loading = false;
    }
  }

  async function validateProvider() {
    if (!selectedProvider || !apiKey) {
      error = "Provider and API key are required";
      return;
    }
    loading = true;
    error = "";
    try {
      const result = await api.validateProviders("aizen", [
        { provider: selectedProvider, api_key: apiKey, model, base_url: baseUrl || undefined },
      ]);
      providerValidation = result?.results?.[0] ?? { valid: false, error: "No response" };
      if (providerValidation.valid) {
        // Save provider
        await api.createSavedProvider({
          provider: selectedProvider,
          api_key: apiKey,
          model,
          base_url: baseUrl || undefined,
        });
        currentStep = "instance";
      }
    } catch (e) {
      error = (e as Error).message;
    } finally {
      loading = false;
    }
  }

  async function createInstance() {
    if (!instanceName.trim()) {
      error = "Instance name is required";
      return;
    }
    creating = true;
    error = "";
    try {
      const result = await api.postWizard("aizen", {
        name: instanceName.trim(),
        providers: [{ provider: selectedProvider, api_key: apiKey, model, base_url: baseUrl || undefined }],
      });
      instanceResult = result;
      currentStep = "finish";
    } catch (e) {
      error = (e as Error).message;
    } finally {
      creating = false;
    }
  }

  function skipWizard() {
    goto("/");
  }

  const providerOptions = [
    { value: "openai", label: "OpenAI" },
    { value: "anthropic", label: "Anthropic" },
    { value: "google", label: "Google Gemini" },
    { value: "ollama", label: "Ollama (Local)" },
    { value: "openrouter", label: "OpenRouter" },
    { value: "custom", label: "Custom OpenAI-compatible" },
  ];
</script>

<div class="wizard-container">
  {#if checking}
    <div class="loading-state">Checking setup status...</div>
  {:else}
    <!-- Progress -->
    <div class="progress-bar">
      {#each ["welcome", "provider", "validate", "instance", "finish"] as step, i}
        <div class="step-indicator" class:active={currentStep === step} class:completed={
          ["welcome", "provider", "validate", "instance", "finish"].indexOf(currentStep) > i
        }>
          <div class="step-number">{i + 1}</div>
          <div class="step-label">{step}</div>
        </div>
        {#if i < 4}
          <div class="step-connector" class:active={
            ["welcome", "provider", "validate", "instance", "finish"].indexOf(currentStep) > i
          }></div>
        {/if}
      {/each}
    </div>

    <!-- Error -->
    {#if error}
      <div class="error-banner">{error}</div>
    {/if}

    <!-- Step: Welcome -->
    {#if currentStep === "welcome"}
      <div class="step-content">
        <h1>Welcome to Aizen</h1>
        <p class="subtitle">Let's get your first agent up and running.</p>

        <div class="info-cards">
          <div class="info-card">
            <div class="info-icon">1</div>
            <div class="info-text">
              <h3>Configure Provider</h3>
              <p>Add your LLM API key (OpenAI, Anthropic, Gemini, or custom)</p>
            </div>
          </div>
          <div class="info-card">
            <div class="info-icon">2</div>
            <div class="info-text">
              <h3>Validate Connection</h3>
              <p>Test the connection and save your provider settings</p>
            </div>
          </div>
          <div class="info-card">
            <div class="info-icon">3</div>
            <div class="info-text">
              <h3>Create Agent</h3>
              <p>Spawn your first Aizen instance with the configured provider</p>
            </div>
          </div>
        </div>

        <div class="actions">
          <button class="btn-primary" onclick={() => currentStep = "provider"}>
            Get Started
          </button>
          <button class="btn-secondary" onclick={skipWizard}>
            Skip for now
          </button>
        </div>
      </div>
    {/if}

    <!-- Step: Provider -->
    {#if currentStep === "provider"}
      <div class="step-content">
        <h2>Configure LLM Provider</h2>
        <p class="subtitle">Enter your API credentials. Data stays local.</p>

        <div class="form">
          <label>
            <span>Provider</span>
            <select bind:value={selectedProvider}>
              <option value="">Select provider...</option>
              {#each providerOptions as opt}
                <option value={opt.value}>{opt.label}</option>
              {/each}
            </select>
          </label>

          <label>
            <span>API Key</span>
            <input
              type="password"
              bind:value={apiKey}
              placeholder="sk-..."
            />
          </label>

          {#if selectedProvider === "custom"}
            <label>
              <span>Base URL</span>
              <input
                type="url"
                bind:value={baseUrl}
                placeholder="https://api.example.com/v1"
              />
            </label>
          {/if}

          <div class="model-row">
            <label class="flex-grow">
              <span>Model</span>
              <input
                type="text"
                bind:value={model}
                placeholder="e.g. gpt-4o, claude-sonnet-4-20250514"
              />
            </label>
            <button
              class="btn-small"
              onclick={fetchModels}
              disabled={!selectedProvider || !apiKey || loading}
            >
              {loading ? "Loading..." : "Fetch Models"}
            </button>
          </div>

          {#if models.length > 0}
            <div class="model-suggestions">
              <span>Suggestions:</span>
              {#each models.slice(0, 5) as m}
                <button class="chip" onclick={() => model = m}>{m}</button>
              {/each}
            </div>
          {/if}
        </div>

        <div class="actions">
          <button class="btn-secondary" onclick={() => currentStep = "welcome"}>Back</button>
          <button
            class="btn-primary"
            onclick={() => currentStep = "validate"}
            disabled={!selectedProvider || !apiKey}
          >
            Continue
          </button>
        </div>
      </div>
    {/if}

    <!-- Step: Validate -->
    {#if currentStep === "validate"}
      <div class="step-content">
        <h2>Validate Provider</h2>
        <p class="subtitle">Test the connection before saving.</p>

        <div class="validation-summary">
          <div class="summary-row">
            <span>Provider</span>
            <code>{selectedProvider}</code>
          </div>
          <div class="summary-row">
            <span>Model</span>
            <code>{model || "(default)"}</code>
          </div>
          {#if baseUrl}
            <div class="summary-row">
              <span>Base URL</span>
              <code>{baseUrl}</code>
            </div>
          {/if}
        </div>

        {#if providerValidation}
          <div class="validation-result" class:success={providerValidation.valid} class:error={!providerValidation.valid}>
            {#if providerValidation.valid}
              <div class="result-icon">✓</div>
              <div class="result-text">
                <strong>Connection successful</strong>
                {#if providerValidation.latency_ms}
                  <span>Latency: {providerValidation.latency_ms}ms</span>
                {/if}
              </div>
            {:else}
              <div class="result-icon">✗</div>
              <div class="result-text">
                <strong>Connection failed</strong>
                <span>{providerValidation.error || "Unknown error"}</span>
              </div>
            {/if}
          </div>
        {/if}

        <div class="actions">
          <button class="btn-secondary" onclick={() => currentStep = "provider"}>Back</button>
          <button
            class="btn-primary"
            onclick={validateProvider}
            disabled={loading}
          >
            {loading ? "Validating..." : providerValidation?.valid ? "Save & Continue" : "Test Connection"}
          </button>
        </div>
      </div>
    {/if}

    <!-- Step: Instance -->
    {#if currentStep === "instance"}
      <div class="step-content">
        <h2>Create First Agent</h2>
        <p class="subtitle">Spawn your first Aizen instance.</p>

        <div class="form">
          <label>
            <span>Instance Name</span>
            <input
              type="text"
              bind:value={instanceName}
              placeholder="aizen-1"
            />
          </label>

          <div class="instance-preview">
            <h4>Configuration Preview</h4>
            <div class="preview-row">
              <span>Component</span>
              <code>aizen</code>
            </div>
            <div class="preview-row">
              <span>Name</span>
              <code>{instanceName || "(required)"}</code>
            </div>
            <div class="preview-row">
              <span>Provider</span>
              <code>{selectedProvider}</code>
            </div>
            <div class="preview-row">
              <span>Model</span>
              <code>{model || "(provider default)"}</code>
            </div>
          </div>
        </div>

        <div class="actions">
          <button class="btn-secondary" onclick={() => currentStep = "validate"}>Back</button>
          <button
            class="btn-primary"
            onclick={createInstance}
            disabled={creating || !instanceName.trim()}
          >
            {creating ? "Creating..." : "Create Agent"}
          </button>
        </div>
      </div>
    {/if}

    <!-- Step: Finish -->
    {#if currentStep === "finish"}
      <div class="step-content">
        <h1>Setup Complete</h1>
        <p class="subtitle">Your first agent is ready.</p>

        <div class="finish-card">
          <div class="finish-icon">✓</div>
          <div class="finish-details">
            <h3>{instanceName}</h3>
            <p>Provider: <code>{selectedProvider}</code></p>
            {#if model}
              <p>Model: <code>{model}</code></p>
            {/if}
            {#if instanceResult?.port}
              <p>Port: <code>{instanceResult.port}</code></p>
            {/if}
          </div>
        </div>

        <div class="actions">
          <a href="/" class="btn-primary">Go to Dashboard</a>
          <a href={`/instances/aizen/${instanceName}`} class="btn-secondary">
            Open Agent
          </a>
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  .wizard-container {
    max-width: 640px;
    margin: 0 auto;
    padding: 2rem 1rem;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
  }

  .loading-state {
    text-align: center;
    padding: 4rem;
    color: var(--fg-dim);
    font-family: var(--font-mono);
  }

  .progress-bar {
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 2rem;
    padding: 0 1rem;
  }

  .step-indicator {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
    opacity: 0.4;
    transition: opacity 0.2s;
  }
  .step-indicator.active,
  .step-indicator.completed {
    opacity: 1;
  }
  .step-indicator.completed .step-number {
    background: var(--success);
    border-color: var(--success);
  }
  .step-indicator.active .step-number {
    background: var(--accent);
    border-color: var(--accent);
    box-shadow: 0 0 10px var(--border-glow);
  }

  .step-number {
    width: 2rem;
    height: 2rem;
    border-radius: 50%;
    border: 1px solid var(--border);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: bold;
    font-family: var(--font-mono);
    background: var(--bg-surface);
    transition: all 0.2s;
  }

  .step-label {
    font-size: 0.625rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-family: var(--font-mono);
  }

  .step-connector {
    width: 2rem;
    height: 1px;
    background: var(--border);
    margin: 0 0.5rem;
    position: relative;
    top: -0.5rem;
    transition: background 0.2s;
  }
  .step-connector.active {
    background: var(--success);
  }

  .step-content {
    flex: 1;
    display: flex;
    flex-direction: column;
  }

  h1, h2 {
    font-size: 1.5rem;
    font-weight: 700;
    text-shadow: var(--text-glow);
    margin-bottom: 0.5rem;
  }

  .subtitle {
    color: var(--fg-dim);
    margin-bottom: 2rem;
    font-family: var(--font-mono);
    font-size: 0.875rem;
  }

  .error-banner {
    padding: 0.75rem 1rem;
    background: rgba(255, 0, 0, 0.1);
    color: var(--error);
    border: 1px solid var(--error);
    border-radius: var(--radius);
    margin-bottom: 1.5rem;
    font-size: 0.875rem;
    font-weight: bold;
    font-family: var(--font-mono);
  }

  .info-cards {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .info-card {
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    padding: 1rem;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
  }

  .info-icon {
    width: 2rem;
    height: 2rem;
    border-radius: 50%;
    background: var(--accent);
    color: var(--bg);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    font-size: 0.875rem;
    flex-shrink: 0;
  }

  .info-text h3 {
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.25rem;
  }
  .info-text p {
    font-size: 0.8125rem;
    color: var(--fg-dim);
    margin: 0;
  }

  .form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 2rem;
  }

  label {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }
  label span {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--fg-dim);
    font-weight: 600;
  }

  input, select {
    padding: 0.625rem 0.75rem;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 0.875rem;
    transition: border-color 0.2s;
  }
  input:focus, select:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 8px var(--border-glow);
  }

  .model-row {
    display: flex;
    align-items: flex-end;
    gap: 0.75rem;
  }
  .flex-grow {
    flex: 1;
  }

  .btn-small {
    padding: 0.625rem 0.875rem;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
  }
  .btn-small:hover:not(:disabled) {
    border-color: var(--accent);
    box-shadow: 0 0 8px var(--border-glow);
  }
  .btn-small:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .model-suggestions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.75rem;
    color: var(--fg-dim);
  }
  .chip {
    padding: 0.25rem 0.5rem;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.2s;
  }
  .chip:hover {
    border-color: var(--accent);
    box-shadow: 0 0 6px var(--border-glow);
  }

  .validation-summary {
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1rem;
    margin-bottom: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.875rem;
  }
  .summary-row span {
    color: var(--fg-dim);
  }
  .summary-row code {
    font-family: var(--font-mono);
    font-size: 0.8125rem;
    background: var(--bg);
    padding: 0.25rem 0.5rem;
    border-radius: var(--radius);
  }

  .validation-result {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    border-radius: var(--radius);
    margin-bottom: 1.5rem;
    border: 1px solid;
  }
  .validation-result.success {
    background: rgba(0, 255, 136, 0.05);
    border-color: var(--success);
  }
  .validation-result.error {
    background: rgba(255, 0, 0, 0.05);
    border-color: var(--error);
  }
  .result-icon {
    width: 2.5rem;
    height: 2.5rem;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.25rem;
    font-weight: bold;
    flex-shrink: 0;
  }
  .validation-result.success .result-icon {
    background: var(--success);
    color: var(--bg);
  }
  .validation-result.error .result-icon {
    background: var(--error);
    color: var(--bg);
  }
  .result-text {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .result-text strong {
    font-size: 0.875rem;
  }
  .result-text span {
    font-size: 0.8125rem;
    color: var(--fg-dim);
    font-family: var(--font-mono);
  }

  .instance-preview {
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .instance-preview h4 {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--fg-dim);
    margin: 0;
  }
  .preview-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.875rem;
  }
  .preview-row span {
    color: var(--fg-dim);
  }
  .preview-row code {
    font-family: var(--font-mono);
    font-size: 0.8125rem;
    background: var(--bg);
    padding: 0.25rem 0.5rem;
    border-radius: var(--radius);
  }

  .finish-card {
    display: flex;
    align-items: center;
    gap: 1.5rem;
    padding: 1.5rem;
    background: var(--bg-surface);
    border: 1px solid var(--success);
    border-radius: var(--radius);
    margin-bottom: 2rem;
  }
  .finish-icon {
    width: 3rem;
    height: 3rem;
    border-radius: 50%;
    background: var(--success);
    color: var(--bg);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.5rem;
    font-weight: bold;
    flex-shrink: 0;
  }
  .finish-details h3 {
    font-size: 1.125rem;
    margin-bottom: 0.5rem;
  }
  .finish-details p {
    margin: 0.25rem 0;
    font-size: 0.875rem;
    color: var(--fg-dim);
    font-family: var(--font-mono);
  }
  .finish-details code {
    color: var(--accent);
  }

  .actions {
    display: flex;
    gap: 0.75rem;
    margin-top: auto;
    padding-top: 2rem;
  }

  .btn-primary, .btn-secondary {
    padding: 0.75rem 1.5rem;
    border-radius: var(--radius);
    font-family: var(--font-mono);
    font-size: 0.875rem;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 1px;
    cursor: pointer;
    transition: all 0.2s;
    text-decoration: none;
    text-align: center;
  }

  .btn-primary {
    background: var(--accent);
    color: var(--bg);
    border: 1px solid var(--accent);
  }
  .btn-primary:hover:not(:disabled) {
    box-shadow: 0 0 15px var(--border-glow);
    text-shadow: 0 0 8px var(--bg);
  }
  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    background: var(--bg-surface);
    color: var(--fg);
    border: 1px solid var(--border);
  }
  .btn-secondary:hover {
    border-color: var(--accent);
    box-shadow: 0 0 10px var(--border-glow);
    text-decoration: none;
  }
</style>
