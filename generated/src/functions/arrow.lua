-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/arrow.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local stretchy = require(script.Parent.Parent.stretchy).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode -- Helper function
local function paddedNode(group)
	local node =
		mathMLTree.MathNode.new("mpadded", if Boolean.toJSBoolean(group) then { group } else {})
	node:setAttribute("width", "+0.6em")
	node:setAttribute("lspace", "0.3em")
	return node
end -- Stretchy arrows with an optional argument
defineFunction({
	type = "xArrow",
	names = {
		"\\xleftarrow",
		"\\xrightarrow",
		"\\xLeftarrow",
		"\\xRightarrow",
		"\\xleftrightarrow",
		"\\xLeftrightarrow",
		"\\xhookleftarrow",
		"\\xhookrightarrow",
		"\\xmapsto",
		"\\xrightharpoondown",
		"\\xrightharpoonup",
		"\\xleftharpoondown",
		"\\xleftharpoonup",
		"\\xrightleftharpoons",
		"\\xleftrightharpoons",
		"\\xlongequal",
		"\\xtwoheadrightarrow",
		"\\xtwoheadleftarrow",
		"\\xtofrom",
		-- The next 3 functions are here to support the mhchem extension.
		-- Direct use of these functions is discouraged and may break someday.
		"\\xrightleftarrows",
		"\\xrightequilibrium",
		"\\xleftequilibrium",
		-- The next 3 functions are here only to support the {CD} environment.
		"\\\\cdrightarrow",
		"\\\\cdleftarrow",
		"\\\\cdlongequal",
	},
	props = { numArgs = 1, numOptionalArgs = 1 },
	handler = function(self, ref0, args, optArgs)
		local parser, funcName = ref0.parser, ref0.funcName
		return {
			type = "xArrow",
			mode = parser.mode,
			label = funcName,
			body = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			below = optArgs[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
	-- Flow is unable to correctly infer the type of `group`, even though it's
	-- unambiguously determined from the passed-in `type` above.
	htmlBuilder = function(self, group: ParseNode<"xArrow">, options)
		local style = options.style -- Build the argument groups in the appropriate style.
		-- Ref: amsmath.dtx:   \hbox{$\scriptstyle\mkern#3mu{#6}\mkern#4mu$}%
		-- Some groups can return document fragments.  Handle those by wrapping
		-- them in a span.
		local newOptions = options:havingStyle(style:sup())
		local upperGroup =
			buildCommon:wrapFragment(html:buildGroup(group.body, newOptions, options), options)
		local arrowPrefix = if Array.slice(group.label, 0, 2) --[[ ROBLOX CHECK: check if 'group.label' is an Array ]]
				== "\\x"
			then "x"
			else "cd"
		table.insert(upperGroup.classes, tostring(arrowPrefix) .. "-arrow-pad") --[[ ROBLOX CHECK: check if 'upperGroup.classes' is an Array ]]
		local lowerGroup
		if Boolean.toJSBoolean(group.below) then
			-- Build the lower group
			newOptions = options:havingStyle(style:sub())
			lowerGroup =
				buildCommon:wrapFragment(html:buildGroup(group.below, newOptions, options), options)
			table.insert(lowerGroup.classes, tostring(arrowPrefix) .. "-arrow-pad") --[[ ROBLOX CHECK: check if 'lowerGroup.classes' is an Array ]]
		end
		local arrowBody = stretchy:svgSpan(group, options) -- Re shift: Note that stretchy.svgSpan returned arrowBody.depth = 0.
		-- The point we want on the math axis is at 0.5 * arrowBody.height.
		local arrowShift = -options:fontMetrics().axisHeight + 0.5 * arrowBody.height -- 2 mu kern. Ref: amsmath.dtx: #7\if0#2\else\mkern#2mu\fi
		local upperShift = -options:fontMetrics().axisHeight - 0.5 * arrowBody.height - 0.111 -- 0.111 em = 2 mu
		if
			upperGroup.depth > 0.25 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			or group.label == "\\xleftequilibrium"
		then
			upperShift -= upperGroup.depth -- shift up if depth encroaches
		end -- Generate the vlist
		local vlist
		if Boolean.toJSBoolean(lowerGroup) then
			local lowerShift = -options:fontMetrics().axisHeight
				+ lowerGroup.height
				+ 0.5 * arrowBody.height
				+ 0.111
			vlist = buildCommon:makeVList({
				positionType = "individualShift",
				children = {
					{ type = "elem", elem = upperGroup, shift = upperShift },
					{ type = "elem", elem = arrowBody, shift = arrowShift },
					{ type = "elem", elem = lowerGroup, shift = lowerShift },
				},
			}, options)
		else
			vlist = buildCommon:makeVList({
				positionType = "individualShift",
				children = {
					{ type = "elem", elem = upperGroup, shift = upperShift },
					{ type = "elem", elem = arrowBody, shift = arrowShift },
				},
			}, options)
		end -- $FlowFixMe: Replace this with passing "svg-align" into makeVList.
		table.insert(
			vlist.children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].children[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			].classes,
			"svg-align"
		) --[[ ROBLOX CHECK: check if 'vlist.children[0].children[0].children[1].classes' is an Array ]]
		return buildCommon:makeSpan({ "mrel", "x-arrow" }, { vlist }, options)
	end,
	mathmlBuilder = function(self, group, options)
		local arrowNode = stretchy:mathMLnode(group.label)
		arrowNode:setAttribute(
			"minsize",
			if group.label:charAt(0) == "x" then "1.75em" else "3.0em"
		)
		local node
		if Boolean.toJSBoolean(group.body) then
			local upperNode = paddedNode(mml:buildGroup(group.body, options))
			if Boolean.toJSBoolean(group.below) then
				local lowerNode = paddedNode(mml:buildGroup(group.below, options))
				node = mathMLTree.MathNode.new("munderover", { arrowNode, lowerNode, upperNode })
			else
				node = mathMLTree.MathNode.new("mover", { arrowNode, upperNode })
			end
		elseif Boolean.toJSBoolean(group.below) then
			local lowerNode = paddedNode(mml:buildGroup(group.below, options))
			node = mathMLTree.MathNode.new("munder", { arrowNode, lowerNode })
		else
			-- This should never happen.
			-- Parser.js throws an error if there is no argument.
			node = paddedNode()
			node = mathMLTree.MathNode.new("mover", { arrowNode, node })
		end
		return node
	end,
})
