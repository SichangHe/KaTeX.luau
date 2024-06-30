-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/html.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local ParseError = require(script.Parent.Parent.ParseError).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "html",
	names = { "\\htmlClass", "\\htmlId", "\\htmlStyle", "\\htmlData" },
	props = { numArgs = 2, argTypes = { "raw", "original" }, allowedInText = true },
	handler = function(ref0, args)
		local parser, funcName, token = ref0.parser, ref0.funcName, ref0.token
		local value = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"raw"
		).string
		local body = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		if Boolean.toJSBoolean(parser.settings.strict) then
			parser.settings:reportNonstrict(
				"htmlExtension",
				"HTML extension is disabled on strict mode"
			)
		end
		local trustContext
		local attributes = {}
		repeat --[[ ROBLOX comment: switch statement conversion ]]
			local condition_ = funcName
			if condition_ == "\\htmlClass" then
				attributes.class = value
				trustContext = { command = "\\htmlClass", class = value }
				break
			elseif condition_ == "\\htmlId" then
				attributes.id = value
				trustContext = { command = "\\htmlId", id = value }
				break
			elseif condition_ == "\\htmlStyle" then
				attributes.style = value
				trustContext = { command = "\\htmlStyle", style = value }
				break
			elseif condition_ == "\\htmlData" then
				do
					local data = value:split(",")
					do
						local i = 0
						while
							i
							< data.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
						do
							local keyVal = data[tostring(i)]:split("=")
							if keyVal.length ~= 2 then
								error(ParseError.new("Error parsing key-value for \\htmlData"))
							end
							attributes[
								"data-" .. tostring(keyVal[
									1 --[[ ROBLOX adaptation: added 1 to array index ]]
								]:trim())
							] =
								keyVal[
									2 --[[ ROBLOX adaptation: added 1 to array index ]]
								]:trim()
							i += 1
						end
					end
					trustContext = { command = "\\htmlData", attributes = attributes }
					break
				end
			else
				error(Error.new("Unrecognized html command"))
			end
		until true
		if not Boolean.toJSBoolean(parser.settings:isTrusted(trustContext)) then
			return parser:formatUnsupportedCmd(funcName)
		end
		return {
			type = "html",
			mode = parser.mode,
			attributes = attributes,
			body = ordargument(body),
		}
	end,
	htmlBuilder = function(group, options)
		local elements = html:buildExpression(group.body, options, false)
		local classes = { "enclosing" }
		if Boolean.toJSBoolean(group.attributes.class) then
			table.insert(
				classes,
				error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]] --[[ ...group.attributes.class.trim().split(/\s+/) ]]
			) --[[ ROBLOX CHECK: check if 'classes' is an Array ]]
		end
		local span = buildCommon:makeSpan(classes, elements, options)
		for attr in group.attributes do
			if Boolean.toJSBoolean(attr ~= "class" and group.attributes:hasOwnProperty(attr)) then
				span:setAttribute(attr, group.attributes[tostring(attr)])
			end
		end
		return span
	end,
	mathmlBuilder = function(group, options)
		return mml:buildExpressionRow(group.body, options)
	end,
})
