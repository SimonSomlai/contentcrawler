$(document).ready(function() {
    function setCookie(cname, cvalue, exdays) {
        var d = new Date();
        d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
        var expires = "expires=" + d.toUTCString();
        document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
    }

    function getCookie(cname) {
        var name = cname + "=";
        var ca = document.cookie.split(';');
        for (var i = 0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0) == ' ') {
                c = c.substring(1);
            }
            if (c.indexOf(name) == 0) {
                return c.substring(name.length, c.length);
            }
        }
        return "";
    }

    function checkCookie() {
        var user = getCookie("username");
        if (user != "") {
            alert("Welcome again " + user);
        } else {
            user = prompt("Please enter your name:", "");
            if (user != "" && user != null) {
                setCookie("username", user, 365);
            }
        }
    }

    var delete_cookie = function(name) {
        document.cookie = name + '=;expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    };

    $(".hide-feedback").on("click", function() {
        $("#feedback-form").fadeOut()
        $('.show-feedback').slideDown().removeClass("hidden")
        setCookie("hidden", "true", 2)
    })

    $('.show-feedback').on("click", function() {
        $("#feedback-form").slideDown().removeClass("hidden")
        $('.show-feedback').fadeOut()
        delete_cookie("hidden")
    })

    if (getCookie("hidden") != ""){
      $(".show-feedback").removeClass("hidden")
    }

    if (getCookie("hidden") == ""){
      $("#feedback-form").removeClass("hidden")
    }
})
