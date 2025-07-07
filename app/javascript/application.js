// jQuery
import $ from 'jquery';
window.$ = $;
window.jQuery = $;

// ChoicesJS
import Choices from 'choices.js';
import 'choices.js/public/assets/styles/choices.min.css';
window.Choices = Choices;

// Substitutos dos requires
import '@rails/ujs';
import Turbolinks from 'turbolinks';
import '@rails/activestorage';

// Bootstrap
import 'bootstrap';

// Máscaras
import 'jquery-mask-plugin';
import Inputmask from 'inputmask';
$.jMaskGlobals = $.jMaskGlobals || {};
$.jMaskGlobals.watchDataMask = true;

// FontAwesome
import '@fortawesome/fontawesome-free/css/all.css';

// Seus arquivos locais
import './styles/application.scss';
import './custom_color';
import './mask';
import './totals';
import './debts';
import './cards';
import './main';

// Iniciar Turbolinks (tem que ser depois do import)
Turbolinks.start();