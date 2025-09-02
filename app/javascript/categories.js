document.addEventListener("turbolinks:load", function () {
  // const selectElement = document.querySelector("#category_select");

  // if (selectElement && !selectElement.classList.contains("choices-initialized")) {
  //   new Choices(selectElement, {
  //     placeholder: true,
  //     allowHTML: true,
  //     itemSelectText: "",
  //     callbackOnCreateTemplates: function (template) {
  //       return {
  //         option: (_classNames, data) => {
  //           // Força leitura direta do atributo
  //           const iconUrl = data.customProperties || data.element?.getAttribute("data-custom-properties") || "";

  //           return template(`
  //             <div class="choices__item choices__item--choice" data-choice data-id="${data.id}" data-value="${data.value}" role="option">
  //               <img src="${iconUrl}" alt="" style="height: 20px; width: 20px; object-fit: contain; margin-right: 8px;">
  //               <span>${data.label}</span>
  //             </div>
  //           `);
  //         },
  //         item: (_classNames, data) => {
  //           const iconUrl = data.customProperties || data.element?.getAttribute("data-custom-properties") || "";

  //           return template(`
  //             <div class="choices__item choices__item--selectable" data-item data-id="${data.id}" data-value="${data.value}" aria-selected="true">
  //               <img src="${iconUrl}" alt="" style="height: 20px; width: 20px; object-fit: contain; margin-right: 8px;">
  //               <span>${data.label}</span>
  //             </div>
  //           `);
  //         }
  //       };
  //     }
  //   });

  //   selectElement.classList.add("choices-initialized");
  // }

  const selectElement = document.querySelector("#category_select");

  if (selectElement && !selectElement.classList.contains("choices-initialized")) {
    new Choices(selectElement, {
      placeholder: true,
      allowHTML: true,
      itemSelectText: "",
      shouldSort: false,
      callbackOnCreateTemplates: function (template) {
        return {
          option: (classNames, data) => {
            const iconUrl = data.element.getAttribute('data-custom-properties') || '';
            return template(`
              <div class="${classNames.item} ${classNames.itemChoice}" data-choice data-id="${data.id}" data-value="${data.value}" role="option">
                <img src="${iconUrl}" alt="" style="height: 30px; width: 30px; object-fit: contain; margin-right: 8px; padding: 4px;">
                ${data.label}
              </div>
            `);
          },
          item: (classNames, data) => {
            const iconUrl = data.element.getAttribute('data-custom-properties') || '';
            return template(`
              <div class="${classNames.item} ${classNames.itemSelectable}" data-item data-id="${data.id}" data-value="${data.value}" aria-selected="true">
                <img src="${iconUrl}" alt="" style="height: 30px; width: 30px; object-fit: contain; margin-right: 8px; padding: 4px;">
                ${data.label}
              </div>
            `);
          },
          choice: (classNames, data) => {
            const iconUrl = data.element.getAttribute('data-custom-properties') || '';
            return template(`
              <div class="${classNames.item} ${classNames.itemChoice}" data-choice data-id="${data.id}" data-value="${data.value}">
                <img src="${iconUrl}" alt="" style="height: 30px; width: 30px; object-fit: contain; margin-right: 8px; padding: 4px;">
                ${data.label}
              </div>
            `);
          }
        };
      }
    });

    selectElement.classList.add("choices-initialized");
  }
});