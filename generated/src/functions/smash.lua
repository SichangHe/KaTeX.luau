-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/smash.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
-- smash, with optional [tb], as in AMS
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "smash",
	names = { "\\smash" },
	props = { numArgs = 1, numOptionalArgs = 1, allowedInText = true },
	handler = function(ref0, args, optArgs)
		local parser = ref0.parser
		local smashHeight = false
		local smashDepth = false
		local tbArg = if Boolean.toJSBoolean(optArgs[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			])
			then assertNodeType(
				optArgs[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				"ordgroup"
			)
			else optArgs[1]
		if Boolean.toJSBoolean(tbArg) then
			-- Optional [tb] argument is engaged.
			-- ref: amsmath: \renewcommand{\smash}[1][tb]{%
			--               def\mb@t{\ht}\def\mb@b{\dp}\def\mb@tb{\ht\z@\z@\dp}%
			local letter = ""
			do
				local i = 0
				while
					i
					< tbArg.body.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					local node = tbArg.body[tostring(i)] -- $FlowFixMe: Not every node type has a `text` property.
					letter = node.text
					if letter == "t" then
						smashHeight = true
					elseif letter == "b" then
						smashDepth = true
					else
						smashHeight = false
						smashDepth = false
						break
					end
					i += 1
				end
			end
		else
			smashHeight = true
			smashDepth = true
		end
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "smash",
			mode = parser.mode,
			body = body,
			smashHeight = smashHeight,
			smashDepth = smashDepth,
		}
	end,
	htmlBuilder = function(group, options)
		local node = buildCommon:makeSpan({}, { html:buildGroup(group.body, options) })
		if
			not Boolean.toJSBoolean(group.smashHeight) and not Boolean.toJSBoolean(group.smashDepth)
		then
			return node
		end
		if Boolean.toJSBoolean(group.smashHeight) then
			node.height = 0 -- In order to influence makeVList, we have to reset the children.
			if Boolean.toJSBoolean(node.children) then
				do
					local i = 0
					while
						i
						< node.children.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
					do
						node.children[tostring(i)].height = 0
						i += 1
					end
				end
			end
		end
		if Boolean.toJSBoolean(group.smashDepth) then
			node.depth = 0
			if Boolean.toJSBoolean(node.children) then
				do
					local i = 0
					while
						i
						< node.children.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
					do
						node.children[tostring(i)].depth = 0
						i += 1
					end
				end
			end
		end -- At this point, we've reset the TeX-like height and depth values.
		-- But the span still has an HTML line height.
		-- makeVList applies "display: table-cell", which prevents the browser
		-- from acting on that line height. So we'll call makeVList now.
		local smashedNode = buildCommon:makeVList(
			{ positionType = "firstBaseline", children = { { type = "elem", elem = node } } },
			options
		) -- For spacing, TeX treats \hphantom as a math group (same spacing as ord).
		return buildCommon:makeSpan({ "mord" }, { smashedNode }, options)
	end,
	mathmlBuilder = function(group, options)
		local node = mathMLTree.MathNode.new("mpadded", { mml:buildGroup(group.body, options) })
		if Boolean.toJSBoolean(group.smashHeight) then
			node:setAttribute("height", "0px")
		end
		if Boolean.toJSBoolean(group.smashDepth) then
			node:setAttribute("depth", "0px")
		end
		return node
	end,
})
