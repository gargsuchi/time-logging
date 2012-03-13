$(document).ready(function(){
  initializers();
  Week.init();
});

function initializers() {
  var date = new Date();
  var currentMonth = date.getMonth();
  var currentDate = date.getDate();
  var currentYear = date.getFullYear();
  if (typeof Week === 'undefined') {
    Week = {};
  }

  Week.init = function() {
    var current_date = new Date();
    var start = new Date(current_date.getFullYear(), current_date.getMonth(), current_date.getDate() - current_date.getDay()+1);
    var end = current_date;
    var start_output = start.getDate()+"/"+(start.getMonth()+1)+"/"+start.getFullYear();
    var end_output = end.getDate()+"/"+(end.getMonth()+1)+"/"+end.getFullYear();
    var maxDate = new Date(currentYear, currentMonth, currentDate);
    $('#week_start').val(start_output);
    $('#week_end').val(end_output);
    $('#week_selector').val(start_output+" to "+end_output);
    $('#js_week_start').val(start);
    $('#js_week_end').val(end);
    refreshTableDates();

    $('#week_selector').datepicker({
      maxDate: maxDate,
      showOn: "button",
      buttonImage: "",
      firstDay: 1,
      onSelect: function(select_date) {
        var sd = $(this).datepicker('getDate');
        start = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay()+1);
        end = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay() + 7);
        if(end > maxDate)
          end = maxDate;
        start_output = start.getDate()+"/"+(start.getMonth()+1)+"/"+start.getFullYear();
        end_output = end.getDate()+"/"+(end.getMonth()+1)+"/"+end.getFullYear();
        $('#week_start').val(start_output);
        $('#week_end').val(end_output);
        $('#week_selector').val(start_output+" to "+end_output);
        $('#js_week_start').val(start);
        $('#js_week_end').val(end);
        refreshTableDates();
      },
      beforeShowDay: function(dates) {
          var cssClass = '';
          if(dates >= start && dates <= end)
              cssClass = 'ui-state-highlight ui-state-active';
          return [true, cssClass];
      },
    });
    function createJsonObject(id) {
      var row = {};
      $(id).find("tr").each(function(i) {
        if($(this).attr("class")!="total") {
          $(this).find("td").each(function(y){
            var row_date = (start.getDate()+y-2)+"-"+(start.getMonth()+1)+"-"+start.getFullYear();
            switch(y) {
              case 1: 
                    id = $(this).text().match(/\d+/);
                    row[id] = {}
                  break;
              case 2:
                    row[id][row_date] = {hours:$(this).find("input").val()};
                  break;
              case 3:
                    row[id][row_date] = {hours:$(this).find("input").val()};
                  break;
              case 4:
                    row[id][row_date] = {hours:$(this).find("input").val()};
                  break;
              case 5:
                    row[id][row_date] = {hours:$(this).find("input").val()};
                  break;
              case 6:
                    row[id][row_date] = {hours:$(this).find("input").val()};
                  break;
              case 7:
                    row[id][row_date] = {hours:$(this).find("input").val()};
                  break;
            }
          });
        }
      });
      return row
    }
    
    $("#submit_button").live("click", function(){
      var id;
      $.post("/week_logs/update", {
                  project: JSON.stringify(createJsonObject("#proj_table")),
                  non_project: JSON.stringify(createJsonObject("#non_proj_table"))
      });
    });
  }
  
  $(".hide-button").live("click", function(){
    $(this).parent().parent().hide();
  });
  Week.toggleAddTaskForm = function(button) {
    var form = $('#' + $(button).attr('data-toggle'));
    if(form.hasClass('hidden')) {
      form.removeClass('hidden');
    } else {
      form.addClass('hidden');
      form.find('.add-task-submit').attr('disabled', true);
      form.find('.add-task-id').focus().val('');
      form.find('.error').addClass('hidden').text('');
    }
  };

  Week.addTaskRow = function(data, table) {
    var taskRow = $(data),
      taskTableBody = $(table).find('tbody'),
      firstTaskRow = taskTableBody.find('tr').first();
    if(firstTaskRow && firstTaskRow.hasClass('even')) {
      taskRow.addClass('odd');
    } else {
      taskRow.addClass('even');
    }
    taskTableBody.prepend(taskRow);
    return taskRow;
  };

  Week.validateForm = function(form) {
    var taskIdField = $(form).find('.add-task-id'),
      taskId = taskIdField.val();
    if(taskId.length === 0) {
      return 'Issue ID is required.';
    } else if(!/^\s*\d+\s*$/.test(taskId)) {
      return 'Issue ID should be a number.';
    } else {
      return true;
    }
  };

  $('.head-button').click(function() {
    Week.toggleAddTaskForm(this);
  });
  $('.add-task-cancel').click(function() {
    Week.toggleAddTaskForm(this);
  });
  $('.add-task-form')
  .attr('action', '')
  .submit(function(e) {
    var form = $(this), validOrError = Week.validateForm(this),
      table = $('#' + form.attr('data-table'));
    e.preventDefault();
    if(validOrError === true) {
      var taskTableBody = table.find('tbody'),
        existingTaskId = form.find('.add-task-id').val(),
        existingTask = taskTableBody.find('#' + existingTaskId);
      form.find('.error').addClass('hidden').text('');
      if(existingTask.length > 0) {
        if(existingTask.effect) {
          existingTask.effect('highlight');
        }
        window.location.hash = '#' + existingTaskId;
      } else {
        $.ajax({
          type: 'post',
          url: '/week_logs/add_task',
          data: form.serialize(),
          success: function(data) {
            var taskRow = Week.addTaskRow(data, table);
            if(taskRow.effect) {
              taskRow.effect('highlight');
            }
            form.find('input').not('.add-task-submit').attr('disabled', false);
          },
          error: function(data) {
            form.find('.error').text(data.responseText).removeClass('hidden');
            form.find('input').not('.add-task-submit').attr('disabled', false);
          },
          beforeSend: function() {
            form.find('input').attr('disabled', true);
          }
        });
      }
      form.find('.add-task-submit').attr('disabled', true);
      form.find('.add-task-id').focus().val('');
    } else {
      form.find('.error').text(validOrError).removeClass('hidden');
    }
    return false;
  })
  .find('.add-task-id')
  .change(function() {
    var submitButton = $('#' + $(this).attr('data-disable'));
    submitButton.attr('disabled', $(this).val().length == 0 || /\D+/.test($(this).val()));
  }).keyup(function() {
    var submitButton = $('#' + $(this).attr('data-disable'));
    submitButton.attr('disabled', $(this).val().length == 0 || /\D+/.test($(this).val()));
  });
}

function refreshTableDates() {
      var start = new Date($("#js_week_start").val());
      var end = new Date($("#js_week_end").val());
      var inspect = new Date(start);
      var i = 0;
      var flag = false;
      var maxDate = new Date(inspect.getFullYear(), inspect.getMonth(), inspect.getDate() - inspect.getDay() + 7);
      while(inspect <= maxDate) {
        switch(i) {
          case 0:
              $("th.mon").html("Mon<br/>"+inspect.getDate());
              flag == true ? $(".mon").hide() : $(".mon").show()
            break;
          case 1:
              $("th.tue").html("Tue<br/>"+inspect.getDate());
              flag == true ? $(".tue").hide() : $(".tue").show()
            break;
          case 2:
              $("th.wed").html("Wed<br/>"+inspect.getDate());
              flag == true ? $(".wed").hide() : $(".wed").show()
            break;
          case 3:
              $("th.thu").html("Thu<br/>"+inspect.getDate());
              flag == true ? $(".thu").hide() : $(".thu").show()
            break;
          case 4:
              $("th.fri").html("Fri<br/>"+inspect.getDate());
              flag == true ? $(".fri").hide() : $(".fri").show()
            break;
          case 5:
              $("th.sat").html("Sat<br/>"+inspect.getDate());
              flag == true ? $(".sat").hide() : $(".sat").show()
            break;
          case 6:
              $("th.sun").html("Sun<br/>"+inspect.getDate());
              flag == true ? $(".sun").hide() : $(".sun").show()
            break;
        }
        if(inspect.toDateString() == end.toDateString())
          flag = true;
        i++;
        inspect.setDate(inspect.getDate()+1);
      }
    }
