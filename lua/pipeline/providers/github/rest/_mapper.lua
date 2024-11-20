---@class pipeline.providers.github.rest.Mapper
local M = {}

---By default the workflow.html_url points to the workflow definition file.
---We want to jump to the UI of all the workflow runs instead.
---Example:
---  input: https://github.com/topaxi/pipeline.nvim/blob/main/.github/workflows/dispatch-echo.yaml
---  output: https://github.com/topaxi/pipeline.nvim/actions/workflows/dispatch-echo.yaml
---@param workflow GhWorkflow
local function workflow_url(workflow)
  return workflow.html_url:gsub('blob/main/%.github', 'actions')
end

---@class pipeline.providers.github.rest.Pipeline: pipeline.Pipeline
---@field meta { workflow_path: string }

---@param workflow GhWorkflow
---@return pipeline.providers.github.rest.Pipeline
function M.to_pipeline(workflow)
  return {
    pipeline_id = workflow.id,
    name = workflow.name,
    url = workflow_url(workflow),
    meta = { workflow_path = workflow.path },
  }
end

---@param workflow_run GhWorkflowRun
---@return pipeline.Run
function M.to_run(workflow_run)
  return {
    run_id = workflow_run.id,
    pipeline_id = workflow_run.workflow_id,
    name = workflow_run.head_commit.message:gsub('\n.*', ''),
    url = workflow_run.html_url,
    status = workflow_run.status,
    conclusion = workflow_run.conclusion,
  }
end

---@param workflow_job GhWorkflowRunJob
---@return pipeline.Job
function M.to_job(workflow_job)
  return {
    job_id = workflow_job.id,
    run_id = workflow_job.run_id,
    name = workflow_job.name,
    status = workflow_job.status,
    conclusion = workflow_job.conclusion,
  }
end

---@param job_id integer
---@param workflow_job_step GhWorkflowRunJobStep
---@return pipeline.Step
function M.to_step(job_id, workflow_job_step)
  return {
    step_id = string.format('%s:%s', job_id, workflow_job_step.number),
    job_id = job_id,
    name = workflow_job_step.name,
    status = workflow_job_step.status,
    conclusion = workflow_job_step.conclusion,
  }
end

return M
