-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/includegraphics.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local unitsModule = require(script.Parent.Parent.units)
type Measurement = unitsModule.Measurement
local unitsModule = require(script.Parent.Parent.units)
local calculateSize = unitsModule.calculateSize
local validUnit = unitsModule.validUnit
local makeEm = unitsModule.makeEm
local ParseError = require(script.Parent.Parent.ParseError).default
local Img = require(script.Parent.Parent.domTree).Img
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local domTreeModule = require(script.Parent.Parent.domTree)
type CssStyle = domTreeModule.CssStyle
local function sizeData(str: string): Measurement
	if Boolean.toJSBoolean(RegExp("^[-+]? *(\\d+(\\.\\d*)?|\\.\\d+)$"):test(str)) then
		-- str is a number with no unit specified.
		-- default unit is bp, per graphix package.
		return { number = tonumber(str), unit = "bp" }
	else
		local match = RegExp("([-+]?) *(\\d+(?:\\.\\d*)?|\\.\\d+) *([a-z]{2})"):exec(str)
		if not Boolean.toJSBoolean(match) then
			error(ParseError.new("Invalid size: '" .. tostring(str) .. "' in \\includegraphics"))
		end
		local data = {
			number = tonumber(match[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			] + match[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			-- sign + magnitude, cast to number
			unit = match[
				4 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
		if not Boolean.toJSBoolean(validUnit(data)) then
			error(
				ParseError.new(
					"Invalid unit: '" .. tostring(data.unit) .. "' in \\includegraphics."
				)
			)
		end
		return data
	end
end
defineFunction({
	type = "includegraphics",
	names = { "\\includegraphics" },
	props = { numArgs = 1, numOptionalArgs = 1, argTypes = { "raw", "url" }, allowedInText = false },
	handler = function(ref0, args, optArgs)
		local parser = ref0.parser
		local width = { number = 0, unit = "em" }
		local height = { number = 0.9, unit = "em" } -- sorta character sized.
		local totalheight = { number = 0, unit = "em" }
		local alt = ""
		if
			Boolean.toJSBoolean(optArgs[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			])
		then
			local attributeStr = assertNodeType(
				optArgs[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				"raw"
			).string -- Parser.js does not parse key/value pairs. We get a string.
			local attributes = attributeStr:split(",")
			do
				local i = 0
				while
					i
					< attributes.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					local keyVal = attributes[tostring(i)]:split("=")
					if keyVal.length == 2 then
						local str = keyVal[
							2 --[[ ROBLOX adaptation: added 1 to array index ]]
						]:trim()
						local condition_ = keyVal[
							1 --[[ ROBLOX adaptation: added 1 to array index ]]
						]:trim()
						if condition_ == "alt" then
							alt = str
						elseif condition_ == "width" then
							width = sizeData(str)
						elseif condition_ == "height" then
							height = sizeData(str)
						elseif condition_ == "totalheight" then
							totalheight = sizeData(str)
						else
							error(ParseError.new("Invalid key: '" .. tostring(keyVal[
								1 --[[ ROBLOX adaptation: added 1 to array index ]]
							]) .. "' in \\includegraphics."))
						end
					end
					i += 1
				end
			end
		end
		local src = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"url"
		).url
		if alt == "" then
			-- No alt given. Use the file name. Strip away the path.
			alt = src
			alt = alt:replace(RegExp("^.*[\\\\/]"), "")
			alt = alt:substring(0, alt:lastIndexOf("."))
		end
		if
			not Boolean.toJSBoolean(
				parser.settings:isTrusted({ command = "\\includegraphics", url = src })
			)
		then
			return parser:formatUnsupportedCmd("\\includegraphics")
		end
		return {
			type = "includegraphics",
			mode = parser.mode,
			alt = alt,
			width = width,
			height = height,
			totalheight = totalheight,
			src = src,
		}
	end,
	htmlBuilder = function(group, options)
		local height = calculateSize(group.height, options)
		local depth = 0
		if
			group.totalheight.number
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			depth = calculateSize(group.totalheight, options) - height
		end
		local width = 0
		if
			group.width.number
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			width = calculateSize(group.width, options)
		end
		local style: CssStyle = { height = makeEm(height + depth) }
		if
			width
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			style.width = makeEm(width)
		end
		if
			depth
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			style.verticalAlign = makeEm(-depth)
		end
		local node = Img.new(group.src, group.alt, style)
		node.height = height
		node.depth = depth
		return node
	end,
	mathmlBuilder = function(group, options)
		local node = mathMLTree.MathNode.new("mglyph", {})
		node:setAttribute("alt", group.alt)
		local height = calculateSize(group.height, options)
		local depth = 0
		if
			group.totalheight.number
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			depth = calculateSize(group.totalheight, options) - height
			node:setAttribute("valign", makeEm(-depth))
		end
		node:setAttribute("height", makeEm(height + depth))
		if
			group.width.number
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			local width = calculateSize(group.width, options)
			node:setAttribute("width", makeEm(width))
		end
		node:setAttribute("src", group.src)
		return node
	end,
})
