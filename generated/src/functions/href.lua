-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/href.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local instanceof = LuauPolyfill.instanceof
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local MathNode = require(script.Parent.Parent.mathMLTree).MathNode
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "href",
	names = { "\\href" },
	props = { numArgs = 2, argTypes = { "url", "original" }, allowedInText = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		local body = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local href = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"url"
		).url
		if
			not Boolean.toJSBoolean(parser.settings:isTrusted({ command = "\\href", url = href }))
		then
			return parser:formatUnsupportedCmd("\\href")
		end
		return { type = "href", mode = parser.mode, href = href, body = ordargument(body) }
	end,
	htmlBuilder = function(group, options)
		local elements = html:buildExpression(group.body, options, false)
		return buildCommon:makeAnchor(group.href, {}, elements, options)
	end,
	mathmlBuilder = function(group, options)
		local math_ = mml:buildExpressionRow(group.body, options)
		if not instanceof(math_, MathNode) then
			math_ = MathNode.new("mrow", { math_ })
		end
		math_:setAttribute("href", group.href)
		return math_
	end,
})
defineFunction({
	type = "href",
	names = { "\\url" },
	props = { numArgs = 1, argTypes = { "url" }, allowedInText = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		local href = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"url"
		).url
		if
			not Boolean.toJSBoolean(parser.settings:isTrusted({ command = "\\url", url = href }))
		then
			return parser:formatUnsupportedCmd("\\url")
		end
		local chars = {}
		do
			local i = 0
			while
				i
				< href.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				local c = href[tostring(i)]
				if c == "~" then
					c = "\\textasciitilde"
				end
				table.insert(chars, { type = "textord", mode = "text", text = c }) --[[ ROBLOX CHECK: check if 'chars' is an Array ]]
				i += 1
			end
		end
		local body = { type = "text", mode = parser.mode, font = "\\texttt", body = chars }
		return { type = "href", mode = parser.mode, href = href, body = ordargument(body) }
	end,
})
