import $ from 'jquery';
import 'select2/dist/js/select2.full.js';
import 'select2/dist/css/select2.css';

if (typeof $.fn.select2 === 'undefined') {
  console.warn('Select2 NÃO foi carregado corretamente no jQuery.');
} else {
  console.log('Select2 carregado com sucesso no jQuery.');
}

export default $;