document.addEventListener('turbolinks:load', function() {
  const mobileMonthSelect = document.getElementById('mobile-month-select');

  if (mobileMonthSelect) {
    mobileMonthSelect.addEventListener('change', function() {
      const selectedMonth = this.value; // Pega o valor selecionado
      window.location.href = `/totals?month=${selectedMonth}`; // Redireciona para a URL com o mês selecionado
    });
  }
});