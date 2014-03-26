$(document).ready(function() {
    $('.nojs').hide();
});

var BookBuilderStatus = '';

function update_status(url) {
    $.getJSON(url, function(data) {
        console.log(data.status);
        if ((data.status == 'pending') ||
            (data.status == 'taken')) {
            var funct = 'update_status("' + url + '")';
            setTimeout(funct, 1000);
            console.log("Replacing with " + bbstatus[data.status]);
        }
        else if (data.status == 'completed') {
            var phref = $('a.produced').attr('href');
            $('a.produced').attr('href', phref + data.produced);
            console.log(bbstatus[data.status]);
        }
        else if (data.status == 'failed') {
            $('pre.errors').text(data.errors);
            console.log(data.errors);
        }

        if (data.status != BookBuilderStatus) {
            $('.bbstatus').hide();
            $('span.bbstatusstring').text(bbstatus[data.status]);
            var div = '.' + data.status;
            $(div).show();
            BookBuilderStatus = data.status;
        }
    });
};

