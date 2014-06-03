class @Gush
  constructor: ->
    @workflows = {}

  initialize: ->
    @registerSockets()
    @displayCurrentWorkflows()
    @displayJobsOverview()

  registerSockets: ->
    @registerWorkersSocket()
    @registerWorkflowsSocket()

  displayCurrentWorkflows: ->
    $("table.workflows tbody").empty()
    ($("table.workflows").data("workflows") || []).each (workflow) =>
      @_addWorkflow(workflow)

  displayJobsOverview: ->
    if nodes?
      nodes.each (node) ->
        job = new Job(node)
        $("table.nodes tbody").append(job.render())

  registerWorkersSocket: ->
    workersSocket = new EventSource("/subscribe/workers.status");

    workersSocket.onopen    = this._onOpen;
    workersSocket.onerror   = this._onError;
    workersSocket.onmessage = this._onStatus;
    workersSocket.onclose   = this._onClose;

  registerWorkflowsSocket: ->
    workflowsSocket = new EventSource("/subscribe/workflows.status");

    workflowsSocket.onopen    = this._onOpen;
    workflowsSocket.onerror   = this._onError;
    workflowsSocket.onmessage = this._onWorkflowStatusChange;
    workflowsSocket.onclose   = this._onClose;

  startWorkflow: (workflow, el) ->
    $.ajax
      url: "/start/" + workflow,
      type: "POST",
      error: (response) ->
        console.log(response)

    if el
      el.removeClass("success")
        .addClass("alert")
        .data("action", "stop")
        .text("Stop Workflow")

  stopWorkflow: (workflow, el) ->
    if el
      el.addClass("success")
        .removeClass("alert")
        .data("action", "start")
        .text("Start Workflow")

  createWorkflow: (workflow) ->
    $.ajax
      url: "/create/" + workflow,
      type: "POST",
      error: (response) ->
        console.log(response)
      success: (response) =>
        @_addWorkflow(response);

  _onOpen: ->
    $("#modalBox").foundation("reveal", "close");

  _onError: (error) ->
    $("#modalBox .data").html("<h2>Lost connection with server.</h2> <h3>Reconnecting…</h3>");
    $("#modalBox").foundation("reveal", "open");

  _onClose: ->
    console.log("Connection closed");

  _onStatus: (message) =>
    message = JSON.parse(message.data)

    switch message.status
      when "started"
        @_onJobStart(message)
      when "finished"
        @_onJobSuccess(message)
      when "heartbeat"
        @_onJobHeartbeat(message)
      when "failed"
        @_onJobFail(message)
      else
        console.error("Unkown job status:", message.status, "data: ", message)

  _onWorkflowStatusChange: (message) =>
    message = JSON.parse(message.data)
    workflow = @workflows[message.workflow_id]

    workflow.changeStatus(message.status)
    workflow.updateDates(message)
    $("table.workflows").find("##{message.workflow_id}").replaceWith(workflow.render())

  _onJobStart: (message) =>
    @_markGraphNode(message.workflow_id, message.job, 'status-running')

  _onJobSuccess: (message) =>
    @_markGraphNode(message.workflow_id, message.job, 'status-finished')

    workflow = @workflows[message.workflow_id]
    if workflow
      workflow.updateProgress()
      $("table.workflows").find("##{message.workflow_id}").replaceWith(workflow.render())

  _onJobHeartbeat: (message) =>

  _onJobFail: (message) =>
    @_markGraphNode(message.workflow_id, message.job, 'status-finished status-failed')

    workflow = @workflows[message.workflow_id]
    workflow.markAsFailed();
    $("table.workflows").find("##{message.workflow_id}").replaceWith(workflow.render())

  _addWorkflow: (data) =>
    workflow = new Workflow(data)
    @workflows[data.id] = workflow

    $("table.workflows").append(workflow.render())

  _markGraphNode: ->

