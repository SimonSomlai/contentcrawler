function updateWebsite(){$("#update-button").on("click",function(){console.log("ready for updatez!"),$("#spinner").show();var t=$(this).data("url"),a=new EventSource("/get-articles?scrape_job%5Burl%5D="+t);window.event=a;var e=0,o=0;return table.rows().clear().draw(),$("#datatable1 tbody tr:first-child").remove(),a.addEventListener("message",function(t){var a=table.rows().count(),n=a+1,i=JSON.parse(JSON.parse(t.data)),s=i.message,d=i.url,r=i.amount,c=i.shares;if(void 0!=s){var l="";l+='  <div id="custom-notification-message-'+e+'" data-notify-close="true" data-notify-position="top-left" data-notify-type="success" data-notify-msg=\'<i class="icon-info-sign"></i> '+s+"'></div>",l+="",3==$("#messages #message-box").length&&$("#messages #message-box")[0].remove(),$("#messages").append(l),SEMICOLON.widget.notifications(jQuery("#custom-notification-message-"+e)),e+=1}void 0!=d&&table.row.add([n.toString(),"<a target='_blank' href='"+d.toString()+"'>"+d.toString()+"</a>","","","","","","",""]).draw(!1),void 0!=r&&$(".amount").text(r+" valid articles found!"),void 0!=c&&(c=JSON.parse(c),data=table.row(o).data(),data[2]=c.total,data[3]=c.facebook,data[4]=c.twitter,data[5]=c.linkedin,data[6]=c.pinterest,data[7]=c.google,data[8]=c.comments,$("#datatable1").dataTable().fnUpdate(data,o,void 0,!1),o+=1)},!1),a.addEventListener("error",function(t){t.eventPhase==EventSource.CLOSED&&(a.close(),$("#spinner").hide())},!1),!1})}$(document).ready(function(){updateWebsite()});