<script lang="ts">
  import { tick } from "svelte";

  type NodeType = "task" | "route" | "interrupt" | "agent" | "send" | "transform" | "subgraph";

  interface WorkflowNode {
    id: string;
    type: NodeType;
    config?: Record<string, any>;
  }

  interface WorkflowEdge {
    from: string;
    to: string;
    condition?: string;
  }

  interface Workflow {
    id: string;
    name: string;
    state_schema: Record<string, any>;
    nodes: Record<string, WorkflowNode>;
    edges: WorkflowEdge[];
  }

  let {
    workflow = $bindable<Workflow>({
      id: "",
      name: "",
      state_schema: {},
      nodes: {},
      edges: [],
    }),
    onChange,
  } = $props<{
    workflow: Workflow;
    onChange?: (w: Workflow) => void;
  }>();

  const NODE_W = 160;
  const NODE_H = 48;
  const PALETTE_W = 140;

  const typeLabels: Record<NodeType, string> = {
    task: "Task",
    route: "Route",
    interrupt: "Interrupt",
    agent: "Agent",
    send: "Send",
    transform: "Transform",
    subgraph: "Subgraph",
  };

  const typeColors: Record<NodeType, string> = {
    task: "var(--accent)",
    route: "var(--warning)",
    interrupt: "var(--error)",
    agent: "#a78bfa",
    send: "#22d3ee",
    transform: "#f472b6",
    subgraph: "#a3a3a3",
  };

  // Canvas state
  let canvasWidth = $state(800);
  let canvasHeight = $state(500);
  let scale = $state(1);
  let offsetX = $state(0);
  let offsetY = $state(0);

  // Node positions (auto-layout + manual drag)
  let nodePositions = $state<Record<string, { x: number; y: number }>>({});

  // Drag state
  let draggingNode = $state<string | null>(null);
  let dragStartX = $state(0);
  let dragStartY = $state(0);
  let dragNodeStartX = $state(0);
  let dragNodeStartY = $state(0);

  // Edge creation
  let edgeFrom = $state<string | null>(null);
  let edgeTo = $state<string | null>(null);
  let tempEdgeEnd = $state<{ x: number; y: number } | null>(null);

  // Selection
  let selectedNode = $state<string | null>(null);
  let selectedEdge = $state<number | null>(null);

  // New node form
  let newNodeType = $state<NodeType>("task");
  let newNodeName = $state("");
  let showNewNodeForm = $state(false);
  let newNodePosition = $state<{ x: number; y: number } | null>(null);

  // Auto-layout on mount / workflow change
  $effect(() => {
    if (workflow.nodes && Object.keys(workflow.nodes).length > 0) {
      autoLayout();
    }
  });

  function autoLayout() {
    const nodes = workflow.nodes;
    const edges = workflow.edges;
    const ids = Object.keys(nodes);
    if (ids.length === 0) return;

    // Simple grid layout
    const cols = Math.ceil(Math.sqrt(ids.length));
    const gapX = 200;
    const gapY = 100;
    const startX = 100;
    const startY = 80;

    const newPositions: Record<string, { x: number; y: number }> = {};
    ids.forEach((id, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      newPositions[id] = {
        x: startX + col * gapX,
        y: startY + row * gapY,
      };
    });

    nodePositions = newPositions;
    updateCanvasSize();
  }

  function updateCanvasSize() {
    const positions = Object.values(nodePositions);
    if (positions.length === 0) return;
    const maxX = Math.max(...positions.map((p) => p.x)) + NODE_W + 100;
    const maxY = Math.max(...positions.map((p) => p.y)) + NODE_H + 100;
    canvasWidth = Math.max(800, maxX);
    canvasHeight = Math.max(500, maxY);
  }

  function getNodeCenter(id: string): { x: number; y: number } {
    const pos = nodePositions[id];
    if (!pos) return { x: 0, y: 0 };
    return { x: pos.x + NODE_W / 2, y: pos.y + NODE_H / 2 };
  }

  // Mouse handlers
  function onCanvasMouseDown(e: MouseEvent) {
    const rect = (e.currentTarget as SVGElement).getBoundingClientRect();
    const x = (e.clientX - rect.left) / scale - offsetX;
    const y = (e.clientY - rect.top) / scale - offsetY;

    // Check if clicked on node
    for (const [id, pos] of Object.entries(nodePositions)) {
      if (
        x >= pos.x &&
        x <= pos.x + NODE_W &&
        y >= pos.y &&
        y <= pos.y + NODE_H
      ) {
        if (edgeFrom && edgeFrom !== id) {
          // Complete edge
          addEdge(edgeFrom, id);
          edgeFrom = null;
          tempEdgeEnd = null;
          return;
        }
        draggingNode = id;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        dragNodeStartX = pos.x;
        dragNodeStartY = pos.y;
        selectedNode = id;
        selectedEdge = null;
        return;
      }
    }

    // Clicked on empty canvas
    selectedNode = null;
    selectedEdge = null;
    if (edgeFrom) {
      edgeFrom = null;
      tempEdgeEnd = null;
    }
  }

  function onCanvasMouseMove(e: MouseEvent) {
    if (draggingNode) {
      const dx = (e.clientX - dragStartX) / scale;
      const dy = (e.clientY - dragStartY) / scale;
      nodePositions[draggingNode] = {
        x: Math.max(0, dragNodeStartX + dx),
        y: Math.max(0, dragNodeStartY + dy),
      };
      updateCanvasSize();
    } else if (edgeFrom) {
      const rect = (e.currentTarget as SVGElement)?.getBoundingClientRect?.();
      if (rect) {
        tempEdgeEnd = {
          x: (e.clientX - rect.left) / scale - offsetX,
          y: (e.clientY - rect.top) / scale - offsetY,
        };
      }
    }
  }

  function onCanvasMouseUp() {
    draggingNode = null;
  }

  function onNodeRightClick(e: MouseEvent, id: string) {
    e.preventDefault();
    if (confirm(`Delete node "${id}"?`)) {
      deleteNode(id);
    }
  }

  function startEdge(fromId: string) {
    edgeFrom = fromId;
    const center = getNodeCenter(fromId);
    tempEdgeEnd = { x: center.x, y: center.y };
  }

  function addEdge(from: string, to: string) {
    if (from === to) return;
    // Check duplicate
    const exists = workflow.edges.some((e) => e.from === from && e.to === to);
    if (exists) return;

    workflow.edges = [...workflow.edges, { from, to }];
    notifyChange();
  }

  function deleteNode(id: string) {
    const newNodes = { ...workflow.nodes };
    delete newNodes[id];
    workflow.nodes = newNodes;
    workflow.edges = workflow.edges.filter((e) => e.from !== id && e.to !== id);
    delete nodePositions[id];
    selectedNode = null;
    notifyChange();
  }

  function deleteEdge(index: number) {
    workflow.edges = workflow.edges.filter((_, i) => i !== index);
    selectedEdge = null;
    notifyChange();
  }

  function addNode() {
    if (!newNodeName.trim() || !newNodePosition) return;
    const id = newNodeName.trim();
    if (workflow.nodes[id]) {
      alert(`Node "${id}" already exists`);
      return;
    }

    workflow.nodes = {
      ...workflow.nodes,
      [id]: { id, type: newNodeType },
    };
    nodePositions[id] = { ...newNodePosition };
    showNewNodeForm = false;
    newNodeName = "";
    updateCanvasSize();
    notifyChange();
  }

  function onCanvasDoubleClick(e: MouseEvent) {
    const rect = (e.currentTarget as SVGElement).getBoundingClientRect();
    const x = (e.clientX - rect.left) / scale - offsetX;
    const y = (e.clientY - rect.top) / scale - offsetY;
    newNodePosition = { x: x - NODE_W / 2, y: y - NODE_H / 2 };
    showNewNodeForm = true;
    newNodeName = "";
  }

  function notifyChange() {
    onChange?.(workflow);
  }

  function updateNodeType(id: string, type: NodeType) {
    workflow.nodes = {
      ...workflow.nodes,
      [id]: { ...workflow.nodes[id], type },
    };
    notifyChange();
  }

  function updateNodeConfig(id: string, key: string, value: any) {
    workflow.nodes = {
      ...workflow.nodes,
      [id]: {
        ...workflow.nodes[id],
        config: { ...(workflow.nodes[id]?.config || {}), [key]: value },
      },
    };
    notifyChange();
  }

  function onEdgeClick(index: number) {
    selectedEdge = index;
    selectedNode = null;
  }

  function onEdgeConditionChange(index: number, condition: string) {
    const newEdges = [...workflow.edges];
    newEdges[index] = { ...newEdges[index], condition: condition || undefined };
    workflow.edges = newEdges;
    notifyChange();
  }

  // Palette drag
  let paletteDragType = $state<NodeType | null>(null);

  function onPaletteMouseDown(type: NodeType) {
    paletteDragType = type;
  }

  function onPaletteMouseUp(e: MouseEvent) {
    if (!paletteDragType) return;
    const canvas = document.querySelector(".visual-canvas");
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left) / scale - offsetX;
    const y = (e.clientY - rect.top) / scale - offsetY;
    newNodeType = paletteDragType;
    newNodePosition = { x: x - NODE_W / 2, y: y - NODE_H / 2 };
    showNewNodeForm = true;
    newNodeName = "";
    paletteDragType = null;
  }

  // Keyboard shortcuts
  function onKeyDown(e: KeyboardEvent) {
    if (e.key === "Delete" || e.key === "Backspace") {
      if (selectedNode) {
        deleteNode(selectedNode);
      } else if (selectedEdge !== null) {
        deleteEdge(selectedEdge);
      }
    }
    if (e.key === "Escape") {
      selectedNode = null;
      selectedEdge = null;
      edgeFrom = null;
      tempEdgeEnd = null;
      showNewNodeForm = false;
    }
  }
</script>

<svelte:window onkeydown={onKeyDown} onmouseup={onPaletteMouseUp} />

<div class="visual-editor">
  <!-- Palette -->
  <div class="palette">
    <h3>Nodes</h3>
    <div class="palette-items">
      {#each Object.entries(typeLabels) as [type, label]}
        <div
          class="palette-item"
          style="--type-color: {typeColors[type as NodeType]}"
          onmousedown={() => onPaletteMouseDown(type as NodeType)}
          role="button"
          tabindex="0"
        >
          <span class="palette-dot" style="background: {typeColors[type as NodeType]}"></span>
          <span>{label}</span>
        </div>
      {/each}
    </div>

    <div class="palette-help">
      <p><strong>Double-click</strong> canvas to add node</p>
      <p><strong>Click</strong> node to select</p>
      <p><strong>Drag</strong> node to move</p>
      <p><strong>Shift+click</strong> node to start edge</p>
      <p><strong>Click</strong> target to complete edge</p>
      <p><strong>Delete</strong> to remove selected</p>
      <p><strong>Right-click</strong> node to delete</p>
    </div>
  </div>

  <!-- Canvas -->
  <div class="canvas-area">
    <svg
      class="visual-canvas"
      viewBox="0 0 {canvasWidth} {canvasHeight}"
      onmousedown={onCanvasMouseDown}
      onmousemove={onCanvasMouseMove}
      onmouseup={onCanvasMouseUp}
      ondblclick={onCanvasDoubleClick}
      role="img"
      aria-label="Workflow visual editor"
    >
      <!-- Grid -->
      <defs>
        <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
          <path d="M 40 0 L 0 0 0 40" fill="none" stroke="var(--border)" stroke-width="0.5" opacity="0.3" />
        </pattern>
        <marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
          <polygon points="0 0, 8 3, 0 6" fill="var(--fg-dim)" />
        </marker>
      </defs>
      <rect width={canvasWidth} height={canvasHeight} fill="url(#grid)" />

      <!-- Edges -->
      {#each workflow.edges as edge, i}
        {@const from = getNodeCenter(edge.from)}
        {@const to = getNodeCenter(edge.to)}
        <g class="edge-group" class:selected={selectedEdge === i} onclick={() => onEdgeClick(i)} role="button" tabindex="0">
          <line
            x1={from.x}
            y1={from.y + NODE_H / 2}
            x2={to.x}
            y2={to.y - NODE_H / 2}
            class="edge-line"
            marker-end="url(#arrow)"
          />
          {#if edge.condition}
            <text
              x={(from.x + to.x) / 2}
              y={(from.y + to.y) / 2}
              class="edge-label"
            >{edge.condition}</text>
          {/if}
        </g>
      {/each}

      <!-- Temp edge -->
      {#if edgeFrom && tempEdgeEnd}
        {@const from = getNodeCenter(edgeFrom)}
        <line
          x1={from.x}
          y1={from.y + NODE_H / 2}
          x2={tempEdgeEnd.x}
          y2={tempEdgeEnd.y}
          class="edge-line temp"
          marker-end="url(#arrow)"
        />
      {/if}

      <!-- Nodes -->
      {#each Object.entries(workflow.nodes) as [id, node]}
        {@const pos = nodePositions[id]}
        {#if pos}
          <g
            class="node-group"
            class:selected={selectedNode === id}
            transform="translate({pos.x}, {pos.y})"
            onmousedown={(e) => {
              if (e.shiftKey) {
                e.stopPropagation();
                startEdge(id);
              }
            }}
            oncontextmenu={(e) => onNodeRightClick(e, id)}
            role="button"
            tabindex="0"
          >
            <rect
              width={NODE_W}
              height={NODE_H}
              rx="6"
              class="node-rect"
              style="--node-color: {typeColors[node.type]}"
            />
            <text x="10" y="18" class="node-type" style="fill: {typeColors[node.type]}">
              {typeLabels[node.type]}
            </text>
            <text x="10" y="34" class="node-id">{id.length > 18 ? id.slice(0, 17) + "…" : id}</text>
            <!-- Edge handle (bottom) -->
            <circle cx={NODE_W / 2} cy={NODE_H} r="4" class="edge-handle" />
          </g>
        {/if}
      {/each}
    </svg>

    <!-- New node form overlay -->
    {#if showNewNodeForm && newNodePosition}
      <div
        class="node-form-overlay"
        style="left: {(newNodePosition.x + NODE_W / 2) * scale + offsetX}px; top: {(newNodePosition.y) * scale + offsetY}px"
      >
        <div class="node-form">
          <h4>New Node</h4>
          <label>
            <span>Name</span>
            <input type="text" bind:value={newNodeName} placeholder="node_id" />
          </label>
          <label>
            <span>Type</span>
            <select bind:value={newNodeType}>
              {#each Object.entries(typeLabels) as [type, label]}
                <option value={type}>{label}</option>
              {/each}
            </select>
          </label>
          <div class="form-actions">
            <button class="btn-small" onclick={() => { showNewNodeForm = false; }}>Cancel</button>
            <button class="btn-small btn-primary" onclick={addNode} disabled={!newNodeName.trim()}>
              Add
            </button>
          </div>
        </div>
      </div>
    {/if}
  </div>

  <!-- Properties panel -->
  <div class="properties-panel">
    {#if selectedNode && workflow.nodes[selectedNode]}
      {@const node = workflow.nodes[selectedNode]}
      <h3>Node: {selectedNode}</h3>
      <label>
        <span>Type</span>
        <select
          value={node.type}
          onchange={(e) => updateNodeType(selectedNode!, e.currentTarget.value as NodeType)}
        >
          {#each Object.entries(typeLabels) as [type, label]}
            <option value={type}>{label}</option>
          {/each}
        </select>
      </label>

      <div class="config-section">
        <h4>Config</h4>
        {#each Object.entries(node.config || {}) as [key, value]}
          <label>
            <span>{key}</span>
            <input
              type="text"
              value={JSON.stringify(value)}
              onchange={(e) => {
                try {
                  updateNodeConfig(selectedNode!, key, JSON.parse(e.currentTarget.value));
                } catch {
                  updateNodeConfig(selectedNode!, key, e.currentTarget.value);
                }
              }}
            />
          </label>
        {/each}
        <button
          class="btn-small"
          onclick={() => {
            const key = prompt("Config key:");
            if (key) updateNodeConfig(selectedNode!, key, "");
          }}
        >
          + Add Config
        </button>
      </div>

      <div class="node-actions">
        <button class="btn-small btn-danger" onclick={() => deleteNode(selectedNode!)}>
          Delete Node
        </button>
      </div>
    {:else if selectedEdge !== null && workflow.edges[selectedEdge]}
      {@const edge = workflow.edges[selectedEdge]}
      <h3>Edge</h3>
      <div class="edge-info">
        <p><strong>From:</strong> <code>{edge.from}</code></p>
        <p><strong>To:</strong> <code>{edge.to}</code></p>
      </div>
      <label>
        <span>Condition (optional)</span>
        <input
          type="text"
          value={edge.condition || ""}
          onchange={(e) => onEdgeConditionChange(selectedEdge!, e.currentTarget.value)}
          placeholder="e.g. $state.status == 'ok'"
        />
      </label>
      <button class="btn-small btn-danger" onclick={() => deleteEdge(selectedEdge!)}>
        Delete Edge
      </button>
    {:else}
      <div class="empty-props">
        <p>Select a node or edge to edit properties</p>
        <p class="hint">Double-click canvas to add a new node</p>
      </div>
    {/if}
  </div>
</div>

<style>
  .visual-editor {
    display: flex;
    height: 100%;
    min-height: 500px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    overflow: hidden;
  }

  .palette {
    width: PALETTE_W;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    background: var(--bg-surface);
  }
  .palette h3 {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--fg-dim);
    margin: 0;
  }
  .palette-items {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .palette-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 0.625rem;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    font-size: 0.8125rem;
    cursor: grab;
    transition: all 0.15s;
    user-select: none;
  }
  .palette-item:hover {
    border-color: var(--type-color);
    box-shadow: 0 0 8px var(--type-color);
  }
  .palette-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .palette-help {
    margin-top: auto;
    font-size: 0.6875rem;
    color: var(--fg-dim);
    line-height: 1.6;
  }
  .palette-help p {
    margin: 0.25rem 0;
  }
  .palette-help strong {
    color: var(--fg);
  }

  .canvas-area {
    flex: 1;
    position: relative;
    overflow: auto;
    background: var(--bg);
  }
  .visual-canvas {
    width: 100%;
    height: 100%;
    min-width: canvasWidth;
    min-height: canvasHeight;
    cursor: crosshair;
  }

  .edge-group {
    cursor: pointer;
  }
  .edge-line {
    stroke: var(--fg-dim);
    stroke-width: 1.5;
    opacity: 0.6;
    transition: all 0.15s;
  }
  .edge-group:hover .edge-line,
  .edge-group.selected .edge-line {
    stroke: var(--accent);
    opacity: 1;
    stroke-width: 2;
  }
  .edge-line.temp {
    stroke: var(--accent);
    stroke-dasharray: 4 4;
    opacity: 0.8;
  }
  .edge-label {
    font-size: 10px;
    font-family: var(--font-mono);
    fill: var(--fg-dim);
    text-anchor: middle;
    dominant-baseline: middle;
    background: var(--bg);
  }

  .node-group {
    cursor: grab;
    transition: filter 0.15s;
  }
  .node-group:hover {
    filter: brightness(1.2);
  }
  .node-group.selected {
    filter: drop-shadow(0 0 6px var(--node-color));
  }
  .node-rect {
    fill: var(--bg-surface);
    stroke: var(--node-color);
    stroke-width: 2;
    transition: all 0.15s;
  }
  .node-type {
    font-size: 9px;
    font-family: var(--font-mono);
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .node-id {
    font-size: 11px;
    font-family: var(--font-mono);
    fill: var(--fg);
  }
  .edge-handle {
    fill: var(--fg-dim);
    cursor: crosshair;
    opacity: 0;
    transition: opacity 0.15s;
  }
  .node-group:hover .edge-handle {
    opacity: 1;
  }

  .node-form-overlay {
    position: absolute;
    transform: translate(-50%, -100%);
    z-index: 10;
  }
  .node-form {
    background: var(--bg-surface);
    border: 1px solid var(--accent);
    border-radius: var(--radius);
    padding: 1rem;
    min-width: 200px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
  }
  .node-form h4 {
    margin: 0 0 0.75rem 0;
    font-size: 0.875rem;
  }
  .node-form label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    margin-bottom: 0.75rem;
  }
  .node-form label span {
    font-size: 0.6875rem;
    text-transform: uppercase;
    color: var(--fg-dim);
  }
  .node-form input,
  .node-form select {
    padding: 0.375rem 0.5rem;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 0.8125rem;
  }
  .form-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
  }

  .properties-panel {
    width: 220px;
    flex-shrink: 0;
    border-left: 1px solid var(--border);
    padding: 1rem;
    background: var(--bg-surface);
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    overflow-y: auto;
  }
  .properties-panel h3 {
    font-size: 0.875rem;
    margin: 0;
    word-break: break-all;
  }
  .properties-panel h4 {
    font-size: 0.75rem;
    text-transform: uppercase;
    color: var(--fg-dim);
    margin: 0.5rem 0 0.25rem 0;
  }
  .properties-panel label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .properties-panel label span {
    font-size: 0.6875rem;
    text-transform: uppercase;
    color: var(--fg-dim);
  }
  .properties-panel input,
  .properties-panel select {
    padding: 0.375rem 0.5rem;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 0.8125rem;
  }
  .properties-panel code {
    font-size: 0.8125rem;
    color: var(--accent);
  }
  .edge-info p {
    margin: 0.25rem 0;
    font-size: 0.8125rem;
  }
  .config-section {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .node-actions {
    margin-top: auto;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
  }
  .empty-props {
    text-align: center;
    color: var(--fg-dim);
    font-size: 0.8125rem;
    padding: 2rem 0;
  }
  .empty-props .hint {
    font-size: 0.75rem;
    margin-top: 0.5rem;
  }

  .btn-small {
    padding: 0.375rem 0.625rem;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.15s;
  }
  .btn-small:hover:not(:disabled) {
    border-color: var(--accent);
  }
  .btn-small:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .btn-primary {
    background: var(--accent);
    color: var(--bg);
    border-color: var(--accent);
  }
  .btn-danger {
    color: var(--error);
    border-color: var(--error);
  }
  .btn-danger:hover {
    background: rgba(255, 0, 0, 0.1);
  }
</style>
