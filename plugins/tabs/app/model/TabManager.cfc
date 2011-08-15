/**
 * @accessors true
 * @singleton
 */
component {

	property configPath;
	property eventMapper;
	property fileSystem;

	public any function init() {

		variables.configPath = "/config/tabs.xml";
		variables.loaded = false;
		return this;

	}

	private void function lazyLoad() {

		if (!variables.loaded) {
			variables.loaded = true;
			loadConfig();
		}

	}

	public struct function getConfig() {

		lazyLoad();

		return config;

	}

	public string function getTab(string controller, string action) {

		lazyLoad();

		if (!structKeyExists(arguments, "controller")) {
			arguments.controller = coldmvc.event.getController();
		}

		if (!structKeyExists(arguments, "action")) {
			arguments.action = coldmvc.event.getAction();
		}

		var event = getEvent(arguments.controller, arguments.action);

		if (structKeyExists(variables.config.events, event)) {
			return variables.config.events[event].name;
		} else {
			return "";
		}

	}

	public array function getTabs(numeric level=1, string controller, string action, string group, string querystring="") {

		lazyLoad();

		if (!structKeyExists(arguments, "controller")) {
			arguments.controller = coldmvc.event.getController();
		}

		if (!structKeyExists(arguments, "action")) {
			arguments.action = coldmvc.event.getAction();
		}

		var event = getEvent(arguments.controller, arguments.action);
		var tabs = [];
		var code = "";

		if (structKeyExists(arguments, "group")) {

			if (structKeyExists(variables.config.groups, arguments.group)) {
				tabs = variables.config.groups[arguments.group];
			}

			// code = variables.config.events[arguments.event].code;

		}
		else {

			var tabs = [];

			if (structKeyExists(variables.config.parents, event)) {

				var tab = variables.config.parents[event];
				var found = false;

				while (!found) {

					if (structKeyExists(tab, "level") && tab.level == level) {
						found = true;
					}
					else if (structKeyExists(tab, "parent")) {
						tab = tab.parent;
					}
					else {
						found = true;
					}

				}

				if (structKeyExists(tab, "event")) {

					tab = variables.config.events[tab.event];
					code = tab.code;

					if (structKeyExists(variables.config.events, tab.parent)) {
						tabs = variables.config.events[tab.parent].tabs;
					}
					else {
						tabs = variables.config.tabs;
					}

				}

			}

		}

		var result = [];
		var i = "";

		for (i = 1; i <= arrayLen(tabs); i++) {

			if (!tabs[i].hidden) {

				var tab = {};
				tab.name = tabs[i].name;
				tab.title = tabs[i].title;
				tab.target = tabs[i].target;
				tab.controller = tabs[i].controller;
				tab.action = tabs[i].action;
				tab.event = tabs[i].event;
				tab.url = tabs[i].url;
				tab.querystring = tabs[i].querystring;

				if (arguments.querystring != "") {
					tab.url = coldmvc.url.addQueryString(tab.url, arguments.querystring);
				}

				// if a model was passed in, rebuild the url
				if (structKeyExists(arguments, "model")) {
					tab.url = coldmvc.link.to({controller=tab.controller, action=tab.action, id=arguments.model}, coldmvc.querystring.combine(tab.querystring, arguments.querystring));
				}

				tab.active = (tabs[i].code == code) ? true : false;
				tab.selected = (tabs[i].event == event) ? true : false;

				tab.class = [];

				if (tab.active) {
					arrayAppend(tab.class, "active");
				}

				if (tab.selected) {
					arrayAppend(tab.class, "selected");
				}

				tab.class = arrayToList(tab.class, " ");

				arrayAppend(result, tab);

			}

		}

		return result;

	}

	public string function renderTabs(required array tabs, string id="", string class="") {

		var html = [];
		var i = "";
		var length = arrayLen(tabs);
		var tag = "<ul";

		if (id != "") {
			tag = tag & ' id="#id#"';
		}

		if (class != "") {
			tag = tag & ' class="#class#"';
		}

		tag = tag & ">";

		arrayAppend(html, tag);

		for (i = 1; i <= length; i++) {

			var tab = tabs[i];
			var tabHTML = [];

			arrayAppend(tabHTML, '<li');

			var tabClass = listToArray(tab.class, " ");

			if (i == 1) {
				arrayAppend(tabClass, "first");
			}

			if (i == length) {
				arrayAppend(tabClass, "last");
			}

			tabClass = arrayToList(tabClass, " ");

			if (tabClass != "") {
				arrayAppend(tabHTML, ' class="#tabClass#"');
			}

			arrayAppend(tabHTML, '><a href="#tab.url#" title="#tab.title#"');

			if (tab.target != "") {
				arrayAppend(tabHTML, ' target="#tab.target#"');
			}

			arrayAppend(tabHTML, '><span>#tab.name#</span></a></li>');

			arrayAppend(html, arrayToList(tabHTML, ""));

		}

		arrayAppend(html, '</ul>');

		return arrayToList(html, chr(10));

	}

	private void function loadConfig() {

		if (!fileSystem.fileExists(variables.configPath)) {
			variables.configPath = expandPath(variables.configPath);
		}

		var xml = xmlParse(fileRead(variables.configPath));

		variables.config = {};
		variables.config.events = {};
		variables.config.codes = {};
		variables.config.groups = {};
		variables.config.tabs = loadTabs(xml, 1, "", "");
		variables.config.parents = duplicate(variables.config.events);

		var event = "";
		for (event in variables.config.events) {

			var parent = variables.config.events[event].parent;
			structDelete(variables.config.parents[event], "tabs");

			if (structKeyExists(variables.config.parents, parent)) {
				variables.config.parents[event].parent = variables.config.parents[parent];
			}
			else {
				variables.config.parents[event].parent = {};
			}

		}

	}

	private any function loadTabs(required xml xml, required numeric level, required string controller, required string parent) {

		var tabs = [];

		if (structKeyExists(arguments.xml, "tabs")) {

			if (structKeyExists(arguments.xml.tabs.xmlAttributes, "controller")) {
				controller = arguments.xml.tabs.xmlAttributes.controller;
			}

			if (structKeyExists(arguments.xml.tabs.xmlAttributes, "group")) {
				var group = arguments.xml.tabs.xmlAttributes.group;
			}
			else {
				var group = "";
			}

			if (controller == "") {
				controller = coldmvc.config.get("controller");
			}

			var i = "";
			for (i = 1; i <= arrayLen(arguments.xml.tabs.xmlChildren); i++) {

				var tabXML = arguments.xml.tabs.xmlChildren[i];

				var tab = {};
				tab.name = tabXML.xmlAttributes.name;
				tab.parent = parent;
				tab.level = arguments.level;
				tab.title = coldmvc.xml.get(tabXML, "title", tab.name);
				tab.target = coldmvc.xml.get(tabXML, "target");
				tab.querystring = coldmvc.xml.get(tabXML, "querystring");
				tab.hidden = coldmvc.xml.get(tabXML, "hidden", false);
				tab.controller = coldmvc.xml.get(tabXML, "controller", controller);

				if (structKeyExists(tabXML.xmlAttributes, "action")) {
					tab.action = tabXML.xmlAttributes.action;
				}
				else {
					tab.action = coldmvc.string.camelize(tab.name);
				}

				tab.event = coldmvc.xml.get(tabXML, "event", tab.controller & "." & tab.action);

				if (!find(".", tab.event)) {
					tab.event = tab.controller & "." & tab.event;
				}

				var mapping = eventMapper.getMapping(tab.controller, tab.action);
				tab.requires = mapping.requires;

				if (structKeyExists(variables.config.events, tab.parent)) {
					tab.code = variables.config.events[tab.parent].code & "." & i;
				}
				else {
					tab.code = i;
				}

				if (structKeyExists(tabXML.xmlAttributes, "url")) {

					tab.url = tabXML.xmlAttributes.url;

					if (left(tab.url, 1) == "/") {
						tab.url = coldmvc.link.to(tab.url, tab.querystring);
					}

				}
				else {

					tab.url = coldmvc.link.to({controller=tab.controller, action=tab.action}, tab.querystring);

				}

				variables.config.events[tab.event] = tab;
				variables.config.codes[tab.code] = tab.event;

				tab.tabs = loadTabs(tabXML, tab.level + 1, tab.controller, tab.event);

				arrayAppend(tabs, tab);

			}

			if (group != "") {
				variables.config.groups[group] = tabs;
			}

		}

		return tabs;

	}

	private function getEvent(required string controller, required string action) {

		var mapping = eventMapper.getMapping(arguments.controller, arguments.action);

		if (structKeyExists(variables.config.events, mapping.event)) {
			return mapping.event;
		} else if (structKeyExists(variables.config.events, "index.index")) {
			return "index.index";
		} else {
			return "";
		}

	}

}