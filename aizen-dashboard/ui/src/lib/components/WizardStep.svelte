<script lang="ts">
  let {
    step,
    value = "",
    onchange,
  } = $props<{
    step: {
      id: string;
      title: string;
      description?: string;
      type: string;
      options?: Array<{
        value: string;
        label: string;
        description?: string;
        recommended?: boolean;
      }>;
      required?: boolean;
      default_value?: string;
    };
    value: string;
    onchange: (value: string) => void;
  }>();

  // Searchable dropdown state (for select with many options)
  const SEARCHABLE_THRESHOLD = 10;
  let searchQuery = $state("");
  let dropdownOpen = $state(false);

  let isSearchable = $derived(
    step.type === "select" &&
      (step.options?.length || 0) > SEARCHABLE_THRESHOLD,
  );

  let filteredOptions = $derived(
    isSearchable && searchQuery
      ? (step.options || []).filter(
          (o) =>
            o.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
            o.value.toLowerCase().includes(searchQuery.toLowerCase()) ||
            (o.description || "")
              .toLowerCase()
              .includes(searchQuery.toLowerCase()),
        )
      : step.options || [],
  );

  let selectedOption = $derived(
    (step.options || []).find((o) => o.value === value),
  );
  let selectedLabel = $derived(
    selectedOption
      ? selectedOption.recommended
        ? `${selectedOption.label} (recommended)`
        : selectedOption.label
      : "",
  );

  function selectOption(optValue: string) {
    onchange(optValue);
    dropdownOpen = false;
    searchQuery = "";
  }

  function handleSearchInput(e: Event) {
    searchQuery = (e.target as HTMLInputElement).value;
    dropdownOpen = true;
  }

  function handleSearchFocus() {
    dropdownOpen = true;
  }

  function handleSearchBlur() {
    // Delay to allow click on option
    setTimeout(() => {
      dropdownOpen = false;
    }, 200);
  }
</script>

<div class="wizard-step">
  <div class="step-title">{step.title}</div>
  {#if step.description}
    <p class="step-description">{step.description}</p>
  {/if}

  {#if step.type === "select" && isSearchable}
    <!-- Searchable dropdown for select with many options -->
    <div class="searchable-select">
      <input
        type="text"
        class="search-input"
        placeholder={selectedLabel || "Search..."}
        value={dropdownOpen ? searchQuery : selectedLabel}
        oninput={handleSearchInput}
        onfocus={handleSearchFocus}
        onblur={handleSearchBlur}
      />
      {#if dropdownOpen}
        <div class="dropdown">
          {#each filteredOptions as option}
            <button
              class="dropdown-item"
              class:selected={value === option.value}
              onmousedown={() => selectOption(option.value)}
            >
              <div class="dropdown-item-header">
                <strong>{option.label}</strong>
                {#if option.recommended}
                  <span class="rec-badge">recommended</span>
                {/if}
              </div>
              {#if option.description}
                <span class="dropdown-item-desc">{option.description}</span>
              {/if}
            </button>
          {:else}
            <div class="dropdown-empty">No matches</div>
          {/each}
        </div>
      {/if}
    </div>
  {:else if step.type === "select"}
    <div class="options">
      {#each step.options || [] as option}
        <button
          class="option-btn"
          class:selected={value === option.value}
          onclick={() => onchange(option.value)}
        >
          <div class="option-header">
            <strong>{option.label}</strong>
            {#if option.recommended}
              <span class="rec-badge">recommended</span>
            {/if}
          </div>
          {#if option.description}<span>{option.description}</span>{/if}
        </button>
      {/each}
    </div>
  {:else if step.type === "multi_select"}
    <div class="options multi">
      {#each step.options || [] as option}
        {@const selected = value.split(",").includes(option.value)}
        <button
          class="option-btn chip"
          class:selected
          onclick={() => {
            const vals = value ? value.split(",").filter(Boolean) : [];
            if (selected)
              onchange(vals.filter((v) => v !== option.value).join(","));
            else onchange([...vals, option.value].join(","));
          }}
        >
          {#if selected}<span class="check">&#10003;</span>{/if}
          <strong>{option.label}</strong>
        </button>
      {/each}
    </div>
  {:else if step.type === "secret"}
    <input
      type="password"
      {value}
      oninput={(e) => onchange(e.currentTarget.value)}
      placeholder="Enter secret..."
    />
  {:else if step.type === "number"}
    <input
      type="number"
      {value}
      oninput={(e) => onchange(e.currentTarget.value)}
    />
  {:else if step.type === "toggle"}
    <label class="toggle">
      <input
        type="checkbox"
        checked={value === "true"}
        onchange={(e) => onchange(String(e.currentTarget.checked))}
      />
      <span class="toggle-slider"></span>
    </label>
  {:else}
    <input
      type="text"
      {value}
      oninput={(e) => onchange(e.currentTarget.value)}
      placeholder="Enter value..."
    />
  {/if}
</div>

<style>
  .wizard-step {
    margin-bottom: 1.5rem;
  }

  .step-title {
    display: block;
    font-size: 0.9rem;
    font-weight: 700;
    color: var(--accent);
    margin-bottom: 0.25rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    text-shadow: var(--text-glow);
  }

  .step-description {
    font-size: 0.8rem;
    color: var(--fg-dim);
    margin-bottom: 0.75rem;
    font-family: var(--font-mono);
  }

  /* Regular options (radio-style buttons) */
  .options {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .options.multi {
    flex-direction: row;
    flex-wrap: wrap;
  }

  .option-btn {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    text-align: left;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: 2px;
    padding: 0.75rem 1rem;
    color: var(--fg);
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .option-btn:hover {
    background: var(--bg-hover);
    border-color: var(--accent);
    box-shadow: 0 0 8px var(--border-glow);
  }

  .option-btn.selected {
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 15%, transparent);
    box-shadow: inset 0 0 8px color-mix(in srgb, var(--accent) 30%, transparent);
  }

  .option-btn strong {
    font-size: 0.875rem;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 1px;
    text-shadow: var(--text-glow);
  }

  .option-btn span {
    font-size: 0.75rem;
    color: var(--fg-dim);
    font-family: var(--font-mono);
  }

  .option-btn.chip {
    flex-direction: row;
    align-items: center;
    gap: 0.35rem;
    padding: 0.5rem 0.75rem;
  }

  .check {
    font-size: 0.75rem;
    color: var(--accent);
    font-weight: 700;
    text-shadow: var(--text-glow);
  }

  .option-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  /* Recommended badge */
  .rec-badge {
    font-size: 0.65rem;
    font-weight: 700;
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    color: var(--accent);
    border: 1px solid var(--accent);
    padding: 0.15rem 0.4rem;
    border-radius: 2px;
    text-transform: uppercase;
    letter-spacing: 1px;
    box-shadow: inset 0 0 3px color-mix(in srgb, var(--accent) 30%, transparent);
  }

  /* Searchable dropdown */
  .searchable-select {
    position: relative;
  }

  .search-input {
    width: 100%;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: 2px;
    padding: 0.625rem 0.875rem;
    color: var(--fg);
    font-size: 0.875rem;
    font-family: var(--font-mono);
    outline: none;
    transition: all 0.2s ease;
    box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .search-input:focus {
    border-color: var(--accent);
    box-shadow: 0 0 8px var(--border-glow);
  }

  .dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    max-height: 320px;
    overflow-y: auto;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-top: none;
    border-radius: 0 0 2px 2px;
    z-index: 100;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(8px);
  }

  .dropdown-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    width: 100%;
    text-align: left;
    background: none;
    border: none;
    border-bottom: 1px dashed color-mix(in srgb, var(--border) 50%, transparent);
    padding: 0.6rem 0.75rem;
    color: var(--fg);
    cursor: pointer;
    transition: all 0.1s ease;
  }

  .dropdown-item:last-child {
    border-bottom: none;
  }

  .dropdown-item:hover {
    background: var(--bg-hover);
    padding-left: 1rem;
    color: var(--accent);
  }

  .dropdown-item.selected {
    background: color-mix(in srgb, var(--accent) 15%, transparent);
    border-left: 3px solid var(--accent);
    padding-left: 1rem;
  }

  .dropdown-item-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .dropdown-item strong {
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  .dropdown-item-desc {
    font-size: 0.75rem;
    color: var(--fg-dim);
    font-family: var(--font-mono);
  }

  .dropdown-empty {
    padding: 0.75rem;
    color: var(--fg-dim);
    font-size: 0.85rem;
    text-align: center;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  /* Inputs */
  input[type="text"],
  input[type="password"],
  input[type="number"] {
    width: 100%;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: 2px;
    padding: 0.625rem 0.875rem;
    color: var(--fg);
    font-size: 0.875rem;
    font-family: var(--font-mono);
    outline: none;
    transition: all 0.2s ease;
    box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  input[type="text"]:focus,
  input[type="password"]:focus,
  input[type="number"]:focus {
    border-color: var(--accent);
    box-shadow: 0 0 8px var(--border-glow);
  }

  input::placeholder {
    color: color-mix(in srgb, var(--fg-dim) 50%, transparent);
  }

  /* Toggle */
  .toggle {
    position: relative;
    display: inline-block;
    width: 44px;
    height: 24px;
    cursor: pointer;
  }

  .toggle input {
    opacity: 0;
    width: 0;
    height: 0;
  }

  .toggle-slider {
    position: absolute;
    inset: 0;
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: 2px;
    transition: all 0.2s ease;
    box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.5);
  }

  .toggle-slider::before {
    content: "";
    position: absolute;
    width: 16px;
    height: 16px;
    left: 4px;
    top: 3px;
    background: var(--fg-dim);
    border-radius: 2px;
    transition: all 0.2s ease;
  }

  .toggle input:checked + .toggle-slider {
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    border-color: var(--accent);
    box-shadow: inset 0 0 10px
      color-mix(in srgb, var(--accent) 30%, transparent);
  }

  .toggle input:checked + .toggle-slider::before {
    transform: translateX(18px);
    background: var(--accent);
    box-shadow: 0 0 5px var(--border-glow);
  }
</style>
