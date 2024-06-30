-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/lap.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
-- @flow
-- Horizontal overlap functions
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local makeEm = require(script.Parent.Parent.units).makeEm
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "lap",
	names = { "\\mathllap", "\\mathrlap", "\\mathclap" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "lap",
			mode = parser.mode,
			alignment = Array.slice(funcName, 5),--[[ ROBLOX CHECK: check if 'funcName' is an Array ]]
			body = body,
		}
	end,
	htmlBuilder = function(group, options)
		-- mathllap, mathrlap, mathclap
		local inner
		if group.alignment == "clap" then
			-- ref: https://www.math.lsu.edu/~aperlis/publications/mathclap/
			inner = buildCommon:makeSpan({}, { html:buildGroup(group.body, options) }) -- wrap, since CSS will center a .clap > .inner > span
			inner = buildCommon:makeSpan({ "inner" }, { inner }, options)
		else
			inner = buildCommon:makeSpan({ "inner" }, { html:buildGroup(group.body, options) })
		end
		local fix = buildCommon:makeSpan({ "fix" }, {})
		local node = buildCommon:makeSpan({ group.alignment }, { inner, fix }, options) -- At this point, we have correctly set horizontal alignment of the
		-- two items involved in the lap.
		-- Next, use a strut to set the height of the HTML bounding box.
		-- Otherwise, a tall argument may be misplaced.
		-- This code resolved issue #1153
		local strut = buildCommon:makeSpan({ "strut" })
		strut.style.height = makeEm(node.height + node.depth)
		if Boolean.toJSBoolean(node.depth) then
			strut.style.verticalAlign = makeEm(-node.depth)
		end
		table.insert(node.children, 1, strut) --[[ ROBLOX CHECK: check if 'node.children' is an Array ]] -- Next, prevent vertical misplacement when next to something tall.
		-- This code resolves issue #1234
		node = buildCommon:makeSpan({ "thinbox" }, { node }, options)
		return buildCommon:makeSpan({ "mord", "vbox" }, { node }, options)
	end,
	mathmlBuilder = function(group, options)
		-- mathllap, mathrlap, mathclap
		local node = mathMLTree.MathNode.new("mpadded", { mml:buildGroup(group.body, options) })
		if group.alignment ~= "rlap" then
			local offset = if group.alignment == "llap" then "-1" else "-0.5"
			node:setAttribute("lspace", tostring(offset) .. "width")
		end
		node:setAttribute("width", "0px")
		return node
	end,
})
