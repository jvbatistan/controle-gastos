document.addEventListener("turbolinks:load", function() {
  $("#debt_has_installment").change(function() {
    if ($(this).is(":checked")) {
      $("#debt_current_installment").removeAttr("disabled");
      $("#debt_final_installment").removeAttr("disabled");
    }
    else {
      $("#debt_current_installment").attr("disabled", true);
      $("#debt_final_installment").attr("disabled", true);
    }
  })
})