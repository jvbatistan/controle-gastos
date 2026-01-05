document.addEventListener("turbolinks:load", function() {
  $(".btn-limpar").click(function(event) {
    event.preventDefault();

    $("input[type='text']").map((index, element) => $(element).val(''))
    $("select").map((index, element) => $(element).val('').eq(0).trigger('change'))
  });

  const selects = document.querySelectorAll('.select2');
  selects.forEach((select) => {
    new Choices(select, {
      removeItemButton: true,
      shouldSort: false
    });
  });
})