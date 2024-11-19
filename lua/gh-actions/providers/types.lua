---@class gh-pipeline.PipelineObject
---@field name? string
---@field action? fun()
---@field url? string
---@field status? string
---@field conclusion? string
---@field meta? table

---A pipeline definition, in Github terms, this would be a workflow.
---@class gh-pipeline.Pipeline: gh-pipeline.PipelineObject
---@field pipeline_id string

---A run of a pipeline, in Github terms, this would be a workflow run.
---@class gh-pipeline.Run: gh-pipeline.PipelineObject
---@field run_id string

---A job within a pipeline run.
---@class gh-pipeline.Job: gh-pipeline.PipelineObject
---@field job_id string

---A step within a job.
---@class gh-pipeline.Step: gh-pipeline.PipelineObject
---@field step_id string
