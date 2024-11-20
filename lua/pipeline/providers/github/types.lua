---@meta

---@class pipeline.providers.github.WorkflowDef
---@field on? { workflow_dispatch?: { inputs?:  pipeline.providers.github.WorkflowDef.DispatchInputs } }

---@alias pipeline.providers.github.WorkflowDef.DispatchInputs table<string, pipeline.providers.github.WorkflowDef.DispatchInput>

---@class pipeline.providers.github.WorkflowDef.DispatchInputBase
---@field description? string
---@field required? boolean
---@field default? string

---@class pipeline.providers.github.WorkflowDef.DispatchInputString: pipeline.providers.github.WorkflowDef.DispatchInputBase
---@field type? 'string'

---@class pipeline.providers.github.WorkflowDef.DispatchInputChoice: pipeline.providers.github.WorkflowDef.DispatchInputBase
---@field type 'choice'
---@field options? string[]

---@alias pipeline.providers.github.WorkflowDef.DispatchInput pipeline.providers.github.WorkflowDef.DispatchInputString | pipeline.providers.github.WorkflowDef.DispatchInputChoice
