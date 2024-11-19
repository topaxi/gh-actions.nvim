---@class pipeline.PipelineObject
---@field name? string
---@field action? fun()
---@field url? string
---@field status? string
---@field conclusion? string
---@field meta? table

---A pipeline definition, in Github terms, this would be a workflow.
---@class pipeline.Pipeline: pipeline.PipelineObject
---@field pipeline_id string

---A run of a pipeline, in Github terms, this would be a workflow run.
---@class pipeline.Run: pipeline.PipelineObject
---@field run_id string

---A job within a pipeline run.
---@class pipeline.Job: pipeline.PipelineObject
---@field job_id string

---A step within a job.
---@class pipeline.Step: pipeline.PipelineObject
---@field step_id string
