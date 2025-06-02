document.addEventListener("turbolinks:load", function () {
  const cards = document.querySelectorAll(".card-option");
  const hiddenField = document.getElementById("selected-card-id");
  const selectedCard = Array.from(cards).find(card => card.dataset.cardSelected === "true");

  if (selectedCard && hiddenField) {
    selectedCard.classList.add("shadow", "selected");
    hiddenField.value = selectedCard.dataset.cardId;
  }

  cards.forEach(card => {
    card.addEventListener("click", () => {
      // Remove destaque de todos
      cards.forEach(c => c.classList.remove("shadow", "selected"));
      
      // Destaca o clicado
      card.classList.add("shadow", "selected");

      // Atualiza o campo hidden
      hiddenField.value = card.dataset.cardId;
    });
  });
});