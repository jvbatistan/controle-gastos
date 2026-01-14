document.addEventListener("click", function (e) {
  const btn = e.target.closest('[data-action="toggle-correction"]');
  if (!btn) return;

  const targetId = btn.getAttribute("data-target");
  const target = document.getElementById(targetId);
  if (!target) return;

  // fecha qualquer outro aberto (opcional, mas fica top)
  document.querySelectorAll('[id^="correction-"]').forEach((el) => {
    if (el !== target) el.classList.add("d-none");
  });

  target.classList.toggle("d-none");

  // foco no select quando abrir
  if (!target.classList.contains("d-none")) {
    const select = target.querySelector("select");
    if (select) select.focus();
  }
});
