function feed_checking() {
  new Ajax.Request('/ajax/feed/checking',
    {
      method:'get',
      onSuccess: function(transport){
        var response = transport.responseText || "no response text";
        if( response == "true" ) {
          $('checking').show()
          $('not_checking').hide()
        } else {
          $('checking').hide()
          $('not_checking').show()
        }
      },
      onFailure: function(){ alert('Something went wrong...') }
    });
}

function admin_feed() {
  feed_checking()
  b = setInterval(feed_checking, 10000);
}

function admin_check_now() {
  new Ajax.Request('/ajax/feed/check', {method:'get'})
  feed_checking()
}

function admin_change_interval() {
  
  new Ajax.Request('/ajax/feed/interval/'+$('interval').value , 
    {
      method:'get',
      onSuccess: function(transport){
        var response = transport.responseText || "0";
        $('interval').value = response
      }
    });
}