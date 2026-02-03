document.addEventListener("turbolinks:load", () => {
  const checkbox = document.getElementById("transaction_has_installments");
  const box = document.getElementById("installments-fields");
  if (!checkbox || !box) return;

  const toggle = () => box.classList.toggle("d-none", !checkbox.checked);

  checkbox.addEventListener("change", toggle);
  toggle();
});