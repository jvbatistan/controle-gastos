document.addEventListener("turbolinks:load", function () {
  Inputmask("999.999.999-99").mask(document.querySelectorAll(".cpf"));

  Inputmask({
    alias: "numeric",
    groupSeparator: ".",
    radixPoint: ",",
    autoGroup: true,
    digits: 2,
    allowMinus: true // Permite valores negativos
  }).mask(document.querySelectorAll(".valor"));
});