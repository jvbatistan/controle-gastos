document.addEventListener("turbolinks:load", () => {
  const checkbox = document.querySelector("#transaction_has_installments");
  const box = document.querySelector("#installments-fields");
  if (!checkbox || !box) return;

  const toggle = () => box.classList.toggle("d-none", !checkbox.checked);

  checkbox.addEventListener("change", toggle);
  toggle();
});
