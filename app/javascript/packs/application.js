require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()
require("channels")
require("jquery-mask-plugin")
// require("jquery")
require("select2")

import $ from "jquery"
window.$ = $
window.jQuery = $

import 'select2'
import 'select2/dist/css/select2.min.css'

import "bootstrap"
import Inputmask from "inputmask";

import "@fortawesome/fontawesome-free/css/all.css";

import "../stylesheet/application"
import "../custom_color"
import "../mask"
import "../totals"
import "../debts"
import "../cards"
import "../main"

$.jMaskGlobals.watchDataMask = true;