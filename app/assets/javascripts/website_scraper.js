// Submitting of index form_for
function submitIndexForm() {
    $('#scrape-form').on('submit', function() {
        console.log("submitted!");
        $("#spinner").show()
        // Get values & make the table ready
        var values = $(this).serialize();
        var url = $("#scrape_job_url").val()
        var table = $("#datatable1").DataTable()
        window.table = table
        // Create a new event which listens for the stream from the server
        var event = new EventSource('/get-articles?' + values + '');
        window.event = event
        var count = 0;

        $("#section-features>h2").text("Searching Articles From " + url + "")
        // Set listener for stream
        var messageCount = 0;
        var dataCount = 0
        event.addEventListener('message', function(e) {
            var rowCount = table.rows().count();
            var rowNumber = rowCount + 1;
            var stream = JSON.parse(JSON.parse(e.data));
            var message = stream.message;
            var url = stream.url;
            var amount = stream.amount;
            var shares = stream.shares

            // Add alert messages to message box
            if (message != undefined) {
                var html = "";
                html += "  <div id=\"custom-notification-message-" + count + "\" data-notify-close=\"true\" data-notify-position=\"top-left\" data-notify-type=\"success\" data-notify-msg='<i class=\"icon-info-sign\"><\/i> " + message + "'><\/div>";
                html += "";
                if ($("#messages #message-box").length == 3) {
                    $("#messages #message-box")[0].remove();
                }
                $("#messages").append(html);
                SEMICOLON.widget.notifications(jQuery("#custom-notification-message-" + count + ""));
                count += 1
            }

            // Add urls to table
            if (url != undefined) {
                table.row.add([
                    rowNumber.toString(),
                    "<a target='_blank' href='" + url.toString() + "'>" + url.toString() + "</a>",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    ""
                ]).draw(false);
            }

            // Add amount to table text
            if (amount != undefined) {
                $(".amount").text(amount + " valid articles found!");
            }

            if (shares != undefined) {
                shares = JSON.parse(shares)
                debugger
                data = table.row(dataCount).data()
                data[2] = shares.total
                data[3] = shares.facebook
                data[4] = shares.twitter
                data[5] = shares.linkedin
                data[6] = shares.pinterest
                data[7] = shares.google
                data[8] = shares.comments

                $('#datatable1').dataTable().fnUpdate(data, dataCount, undefined, false);
                dataCount += 1
            }

        }, false);

        // Close stream when input ends
        event.addEventListener('error', function(e) {
            if (e.eventPhase == EventSource.CLOSED) {
                event.close();
                $("#spinner").hide()
            }
        }, false);

        return false; // prevents normal behaviour
    });
}

$(document).ready(function() {
    submitIndexForm()
})
