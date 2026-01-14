// jQuery
import $ from 'jquery';
window.$ = $;
window.jQuery = $;

// ChoicesJS
import Choices from 'choices.js';
import 'choices.js/public/assets/styles/choices.min.css';
window.Choices = Choices;

// Rails UJS (precisa importar corretamente)
import Rails from '@rails/ujs';
Rails.start();
window.Rails = Rails;

// Turbolinks (não é Turbo)
import Turbolinks from 'turbolinks';
Turbolinks.start();

// ActiveStorage
import * as ActiveStorage from '@rails/activestorage';
ActiveStorage.start();

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
import './categories';
import './main';
import './classification_suggestions';