document.addEventListener("turbolinks:load", function() {
  const hastInstallment    = $("#debt_has_installment");
  const currentInstallment = $("#debt_current_installment");
  const finalInstallment   = $("#debt_final_installment");

  if (hastInstallment.is(":checked")) {
    currentInstallment.removeAttr("disabled");
    finalInstallment.removeAttr("disabled");
  }
  else {
    currentInstallment.attr("disabled", true);
    finalInstallment.attr("disabled", true);
  }

  hastInstallment.change(function() {
    if ($(this).is(":checked")) {
      currentInstallment.removeAttr("disabled");
      finalInstallment.removeAttr("disabled");
    }
    else {
      currentInstallment.attr("disabled", true);
      finalInstallment.attr("disabled", true);
    }
  })
})