document.addEventListener('turbolinks:load', function() {
  const year = document.querySelector("#totals-year");
  const month = document.querySelector("#totals-month");
  const mobileMonthSelect = document.getElementById('mobile-month-select');

  const navigateWith = (updates) => {
    const url = new URL(window.location.href);

    Object.keys(updates).forEach((key) => {
      const val = updates[key];
      if (val === null || val === undefined || val === "") {
        url.searchParams.delete(key);
      } else {
        url.searchParams.set(key, val);
      }
    });

    window.location.href = url.pathname + "?" + url.searchParams.toString();
  };

  // Desktop (ano + mês)
  if (year && month) {
    const go = () => navigateWith({ year: year.value, month: month.value });
    year.addEventListener("change", go);
    month.addEventListener("change", go);
  }

  // Mobile (só mês) — mas mantém o year atual se existir
  if (mobileMonth) {
    mobileMonth.addEventListener("change", () => {
      const currentYear = year ? year.value : (new URL(window.location.href)).searchParams.get("year") || new Date().getFullYear();
      navigateWith({ year: currentYear, month: mobileMonth.value });
    });
  }
});