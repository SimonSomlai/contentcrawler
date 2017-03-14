// Submitting of homepage form
function submitHomeForm() {
    $('#scrape-form-home').on('submit', function() {
        console.log("submitted!");
        $("#spinner").show()
        // Get values & make the table ready
        var values = $(this).serialize();
        var url = $("#scrape_job_url").val()
        var table = $("#datatable1").DataTable()
        window.table = table
        $("#datatable1 tbody tr:first-child").remove();

        // Create a new event which listens for the stream from the server
        var event = new EventSource('/get-home-articles?' + values + '');
        window.event = event

        // Scroll to table
        $('html,body').animate({
            scrollTop: $("#section-features").offset().top - 30
        }, 'slow');

        // Set searching text
        $("#section-features>h2").text("Searching Articles From " + url + "")
        $(".url").text(url)
        $("#url").val(url)
        var count = 0;
        // Set listener for stream
        event.addEventListener('message', function(e) {
            var rowCount = table.rows().count();
            var rowNumber = rowCount + 1;
            var stream = JSON.parse(JSON.parse(e.data));
            var message = stream.message;
            var url = stream.url;
            var amount = stream.amount;
            var error = stream.error;

            // Catches URL errors
            if (error != undefined) {
                alert('Invalid website format. Use \"http://www.mydomain.com/\". Do not forget the last \/')
                location.reload()
            }

            // Add alert messages to message box
            if (message != undefined) {
                var html = "";
                html += "  <div id=\"custom-notification-message-"+ count + "\" data-notify-close=\"true\" data-notify-position=\"top-left\" data-notify-type=\"success\" data-notify-msg='<i class=\"icon-info-sign\"><\/i> " + message + "'><\/div>";
                html += "";
                if ($("#messages #message-box").length == 3) {
                    $("#messages #message-box")[0].remove();
                }
                $("#messages").append(html);
	              SEMICOLON.widget.notifications(jQuery("#custom-notification-message-"+ count +""));
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

        }, false);

        // Close stream when input ends
        event.addEventListener('error', function(e) {
            if (e.eventPhase == EventSource.CLOSED) {
                event.close();
                $(".scrape-button").removeClass("hidden")
                $("#spinner").hide()
            }
        }, false);

        return false;
    });
}

// Scanning first elements on homepage
function homeScan() {
    $(".scrape-button").on("click", function(e) {
        e.preventDefault()
        $("#spinner").show()
        // Order the table first
        table.order([0, 'asc']).draw()
        // Get the first three articles & add them to stream
        var articles = [];
        for (var i = 0; i < 5; i++) {
            articles.push(table.rows().data()[i][1].match(/href='(.+)'/)[0].replace("href=", ""))
        }

        var event = new EventSource('/home-scan?links=' + encodeURIComponent(articles.join(";")));
        $("#messages").empty()

        var rowCount = 0;
        var messageCount = 0;
        // Listen for stream output
        event.addEventListener('message', function(e) {
            var stream = JSON.parse(JSON.parse(e.data));
            var shares = stream.shares;
            var message = stream.message;
            // Selects row, then updates the data

            if (message != undefined) {
                var html = "";
                html += "  <div id=\"custom-notification-message-"+ messageCount +"\" data-notify-close=\"true\" data-notify-position=\"top-left\" data-notify-type=\"success\" data-notify-msg='<i class=\"icon-info-sign\"><\/i> " + message + "'><\/div>";
                html += "";
                if ($("#messages #message-box").length == 3) {
                    $("#messages #message-box")[0].remove();
                }
                $("#messages").append(html);
                SEMICOLON.widget.notifications(jQuery("#custom-notification-message-"+ messageCount +""));
                messageCount += 1
            }

            if (shares != undefined) {
                shares = JSON.parse(shares)
                data = table.row(rowCount).data()
                data[2] = shares.total
                data[3] = shares.facebook
                data[4] = shares.twitter
                data[5] = shares.linkedin
                data[6] = shares.pinterest
                data[7] = shares.google
                data[8] = shares.comments

                $('#datatable1').dataTable().fnUpdate(data, rowCount, undefined, false);
                rowCount += 1
            }
        }, false);

        event.addEventListener('error', function(e) {
            if (e.eventPhase == EventSource.CLOSED) {
                event.close();
                $("#spinner").hide()
                $("#register").modal("show")
            }
        }, false);

        return false; // prevents normal behaviour
    })
}

$(document).ready(function() {
    submitHomeForm()
    homeScan()
})
