import Rails from '@rails/ujs';
import $ from 'jquery';

import DataTable from 'datatables.net-dt';
import Buttons from 'datatables.net-buttons/js/buttons.html5';
import FixedHeader from 'datatables.net-fixedheader-dt';

Rails.start();

window.$ = $;
window.jQuery = $;

// 显式把插件挂到当前 jQuery
DataTable(window, $);
Buttons(window, $);
FixedHeader(window, $);

import './javascripts/autocomplete';
import './javascripts/datatables';
