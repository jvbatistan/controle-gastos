document.addEventListener("turbolinks:load", function() {
  $(".btn-limpar").click(function(event) {
    event.preventDefault();

    $("input[type='text']").map((index, element) => $(element).val(''))
    $("select").map((index, element) => $(element).val(''))
  });
})