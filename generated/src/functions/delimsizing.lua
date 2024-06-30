-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/delimsizing.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
-- @flow
local buildCommon = require(script.Parent.Parent.buildCommon).default
local defineFunction = require(script.Parent.Parent.defineFunction).default
local delimiter = require(script.Parent.Parent.delimiter).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local ParseError = require(script.Parent.Parent.ParseError).default
local utils = require(script.Parent.Parent.utils).default
local parseNodeModule = require(script.Parent.Parent.parseNode)
local assertNodeType = parseNodeModule.assertNodeType
local checkSymbolNodeType = parseNodeModule.checkSymbolNodeType
local makeEm = require(script.Parent.Parent.units).makeEm
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local optionsModule = require(script.Parent.Parent.Options)
type Options = optionsModule.default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type AnyParseNode = parseNodeModule.AnyParseNode
type ParseNode = parseNodeModule.ParseNode
type SymbolParseNode = parseNodeModule.SymbolParseNode
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type FunctionContext = defineFunctionModule.FunctionContext -- Extra data needed for the delimiter handler down below
local delimiterSizes = {
	["\\bigl"] = { mclass = "mopen", size = 1 },
	["\\Bigl"] = { mclass = "mopen", size = 2 },
	["\\biggl"] = { mclass = "mopen", size = 3 },
	["\\Biggl"] = { mclass = "mopen", size = 4 },
	["\\bigr"] = { mclass = "mclose", size = 1 },
	["\\Bigr"] = { mclass = "mclose", size = 2 },
	["\\biggr"] = { mclass = "mclose", size = 3 },
	["\\Biggr"] = { mclass = "mclose", size = 4 },
	["\\bigm"] = { mclass = "mrel", size = 1 },
	["\\Bigm"] = { mclass = "mrel", size = 2 },
	["\\biggm"] = { mclass = "mrel", size = 3 },
	["\\Biggm"] = { mclass = "mrel", size = 4 },
	["\\big"] = { mclass = "mord", size = 1 },
	["\\Big"] = { mclass = "mord", size = 2 },
	["\\bigg"] = { mclass = "mord", size = 3 },
	["\\Bigg"] = { mclass = "mord", size = 4 },
}
local delimiters = {
	"(",
	"\\lparen",
	")",
	"\\rparen",
	"[",
	"\\lbrack",
	"]",
	"\\rbrack",
	"\\{",
	"\\lbrace",
	"\\}",
	"\\rbrace",
	"\\lfloor",
	"\\rfloor",
	"\u{230a}",
	"\u{230b}",
	"\\lceil",
	"\\rceil",
	"\u{2308}",
	"\u{2309}",
	"<",
	">",
	"\\langle",
	"\u{27e8}",
	"\\rangle",
	"\u{27e9}",
	"\\lt",
	"\\gt",
	"\\lvert",
	"\\rvert",
	"\\lVert",
	"\\rVert",
	"\\lgroup",
	"\\rgroup",
	"\u{27ee}",
	"\u{27ef}",
	"\\lmoustache",
	"\\rmoustache",
	"\u{23b0}",
	"\u{23b1}",
	"/",
	"\\backslash",
	"|",
	"\\vert",
	"\\|",
	"\\Vert",
	"\\uparrow",
	"\\Uparrow",
	"\\downarrow",
	"\\Downarrow",
	"\\updownarrow",
	"\\Updownarrow",
	".",
}
type IsMiddle = { delim: string, options: Options } -- Delimiter functions
local function checkDelimiter(delim: AnyParseNode, context: FunctionContext): SymbolParseNode
	local symDelim = checkSymbolNodeType(delim)
	if
		Boolean.toJSBoolean(
			if Boolean.toJSBoolean(symDelim)
				then utils:contains(delimiters, symDelim.text)
				else symDelim
		)
	then
		return symDelim
	elseif Boolean.toJSBoolean(symDelim) then
		error(
			ParseError.new(
				("Invalid delimiter '%s' after '%s'"):format(
					tostring(symDelim.text),
					tostring(context.funcName)
				),
				delim
			)
		)
	else
		error(ParseError.new(("Invalid delimiter type '%s'"):format(tostring(delim.type)), delim))
	end
end
defineFunction({
	type = "delimsizing",
	names = {
		"\\bigl",
		"\\Bigl",
		"\\biggl",
		"\\Biggl",
		"\\bigr",
		"\\Bigr",
		"\\biggr",
		"\\Biggr",
		"\\bigm",
		"\\Bigm",
		"\\biggm",
		"\\Biggm",
		"\\big",
		"\\Big",
		"\\bigg",
		"\\Bigg",
	},
	props = { numArgs = 1, argTypes = { "primitive" } },
	handler = function(context, args)
		local delim = checkDelimiter(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			context
		)
		return {
			type = "delimsizing",
			mode = context.parser.mode,
			size = delimiterSizes[tostring(context.funcName)].size,
			mclass = delimiterSizes[tostring(context.funcName)].mclass,
			delim = delim.text,
		}
	end,
	htmlBuilder = function(group, options)
		if group.delim == "." then
			-- Empty delimiters still count as elements, even though they don't
			-- show anything.
			return buildCommon:makeSpan({ group.mclass })
		end -- Use delimiter.sizedDelim to generate the delimiter.
		return delimiter:sizedDelim(group.delim, group.size, options, group.mode, { group.mclass })
	end,
	mathmlBuilder = function(group)
		local children = {}
		if group.delim ~= "." then
			table.insert(children, mml:makeText(group.delim, group.mode)) --[[ ROBLOX CHECK: check if 'children' is an Array ]]
		end
		local node = mathMLTree.MathNode.new("mo", children)
		if group.mclass == "mopen" or group.mclass == "mclose" then
			-- Only some of the delimsizing functions act as fences, and they
			-- return "mopen" or "mclose" mclass.
			node:setAttribute("fence", "true")
		else
			-- Explicitly disable fencing if it's not a fence, to override the
			-- defaults.
			node:setAttribute("fence", "false")
		end
		node:setAttribute("stretchy", "true")
		local size = makeEm(delimiter.sizeToMaxHeight[tostring(group.size)])
		node:setAttribute("minsize", size)
		node:setAttribute("maxsize", size)
		return node
	end,
})
local function assertParsed(group: ParseNode<"leftright">)
	if not Boolean.toJSBoolean(group.body) then
		error(Error.new("Bug: The leftright ParseNode wasn't fully parsed."))
	end
end
defineFunction({
	type = "leftright-right",
	names = { "\\right" },
	props = { numArgs = 1, primitive = true },
	handler = function(context, args)
		-- \left case below triggers parsing of \right in
		--   `const right = parser.parseFunction();`
		-- uses this return value.
		local color = context.parser.gullet.macros:get("\\current@color")
		if
			Boolean.toJSBoolean(
				if Boolean.toJSBoolean(color) then typeof(color) ~= "string" else color
			)
		then
			error(ParseError.new("\\current@color set to non-string in \\right"))
		end
		return {
			type = "leftright-right",
			mode = context.parser.mode,
			delim = checkDelimiter(
				args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				context
			).text,
			color = color, -- undefined if not set via \color
		}
	end,
})
defineFunction({
	type = "leftright",
	names = { "\\left" },
	props = { numArgs = 1, primitive = true },
	handler = function(context, args)
		local delim = checkDelimiter(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			context
		)
		local parser = context.parser -- Parse out the implicit body
		parser.leftrightDepth += 1 -- parseExpression stops before '\\right'
		local body = parser:parseExpression(false)
		parser.leftrightDepth -= 1 -- Check the next token
		parser:expect("\\right", false)
		local right = assertNodeType(parser:parseFunction(), "leftright-right")
		return {
			type = "leftright",
			mode = parser.mode,
			body = body,
			left = delim.text,
			right = right.delim,
			rightColor = right.color,
		}
	end,
	htmlBuilder = function(group, options)
		assertParsed(group) -- Build the inner expression
		local inner = html:buildExpression(group.body, options, true, { "mopen", "mclose" })
		local innerHeight = 0
		local innerDepth = 0
		local hadMiddle = false -- Calculate its height and depth
		do
			local i = 0
			while
				i
				< inner.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				-- Property `isMiddle` not defined on `span`. See comment in
				-- "middle"'s htmlBuilder.
				-- $FlowFixMe
				if Boolean.toJSBoolean(inner[tostring(i)].isMiddle) then
					hadMiddle = true
				else
					innerHeight = math.max(inner[tostring(i)].height, innerHeight)
					innerDepth = math.max(inner[tostring(i)].depth, innerDepth)
				end
				i += 1
			end
		end -- The size of delimiters is the same, regardless of what style we are
		-- in. Thus, to correctly calculate the size of delimiter we need around
		-- a group, we scale down the inner size based on the size.
		innerHeight *= options.sizeMultiplier
		innerDepth *= options.sizeMultiplier
		local leftDelim
		if group.left == "." then
			-- Empty delimiters in \left and \right make null delimiter spaces.
			leftDelim = html:makeNullDelimiter(options, { "mopen" })
		else
			-- Otherwise, use leftRightDelim to generate the correct sized
			-- delimiter.
			leftDelim = delimiter:leftRightDelim(
				group.left,
				innerHeight,
				innerDepth,
				options,
				group.mode,
				{ "mopen" }
			)
		end -- Add it to the beginning of the expression
		table.insert(inner, 1, leftDelim) --[[ ROBLOX CHECK: check if 'inner' is an Array ]] -- Handle middle delimiters
		if Boolean.toJSBoolean(hadMiddle) then
			do
				local i = 1
				while
					i
					< inner.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					local middleDelim = inner[tostring(i)] -- Property `isMiddle` not defined on `span`. See comment in
					-- "middle"'s htmlBuilder.
					-- $FlowFixMe
					local isMiddle: IsMiddle = middleDelim.isMiddle
					if Boolean.toJSBoolean(isMiddle) then
						-- Apply the options that were active when \middle was called
						inner[tostring(i)] = delimiter:leftRightDelim(
							isMiddle.delim,
							innerHeight,
							innerDepth,
							isMiddle.options,
							group.mode,
							{}
						)
					end
					i += 1
				end
			end
		end
		local rightDelim -- Same for the right delimiter, but using color specified by \color
		if group.right == "." then
			rightDelim = html:makeNullDelimiter(options, { "mclose" })
		else
			local colorOptions = if Boolean.toJSBoolean(group.rightColor)
				then options:withColor(group.rightColor)
				else options
			rightDelim = delimiter:leftRightDelim(
				group.right,
				innerHeight,
				innerDepth,
				colorOptions,
				group.mode,
				{ "mclose" }
			)
		end -- Add it to the end of the expression.
		table.insert(inner, rightDelim) --[[ ROBLOX CHECK: check if 'inner' is an Array ]]
		return buildCommon:makeSpan({ "minner" }, inner, options)
	end,
	mathmlBuilder = function(group, options)
		assertParsed(group)
		local inner = mml:buildExpression(group.body, options)
		if group.left ~= "." then
			local leftNode = mathMLTree.MathNode.new("mo", { mml:makeText(group.left, group.mode) })
			leftNode:setAttribute("fence", "true")
			table.insert(inner, 1, leftNode) --[[ ROBLOX CHECK: check if 'inner' is an Array ]]
		end
		if group.right ~= "." then
			local rightNode =
				mathMLTree.MathNode.new("mo", { mml:makeText(group.right, group.mode) })
			rightNode:setAttribute("fence", "true")
			if Boolean.toJSBoolean(group.rightColor) then
				rightNode:setAttribute("mathcolor", group.rightColor)
			end
			table.insert(inner, rightNode) --[[ ROBLOX CHECK: check if 'inner' is an Array ]]
		end
		return mml:makeRow(inner)
	end,
})
defineFunction({
	type = "middle",
	names = { "\\middle" },
	props = { numArgs = 1, primitive = true },
	handler = function(context, args)
		local delim = checkDelimiter(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			context
		)
		if not Boolean.toJSBoolean(context.parser.leftrightDepth) then
			error(ParseError.new("\\middle without preceding \\left", delim))
		end
		return { type = "middle", mode = context.parser.mode, delim = delim.text }
	end,
	htmlBuilder = function(group, options)
		local middleDelim
		if group.delim == "." then
			middleDelim = html:makeNullDelimiter(options, {})
		else
			middleDelim = delimiter:sizedDelim(group.delim, 1, options, group.mode, {})
			local isMiddle: IsMiddle = { delim = group.delim, options = options } -- Property `isMiddle` not defined on `span`. It is only used in
			-- this file above.
			-- TODO: Fix this violation of the `span` type and possibly rename
			-- things since `isMiddle` sounds like a boolean, but is a struct.
			-- $FlowFixMe
			middleDelim.isMiddle = isMiddle
		end
		return middleDelim
	end,
	mathmlBuilder = function(group, options)
		-- A Firefox \middle will stretch a character vertically only if it
		-- is in the fence part of the operator dictionary at:
		-- https://www.w3.org/TR/MathML3/appendixc.html.
		-- So we need to avoid U+2223 and use plain "|" instead.
		local textNode = if group.delim == "\\vert" or group.delim == "|"
			then mml:makeText("|", "text")
			else mml:makeText(group.delim, group.mode)
		local middleNode = mathMLTree.MathNode.new("mo", { textNode })
		middleNode:setAttribute("fence", "true") -- MathML gives 5/18em spacing to each <mo> element.
		-- \middle should get delimiter spacing instead.
		middleNode:setAttribute("lspace", "0.05em")
		middleNode:setAttribute("rspace", "0.05em")
		return middleNode
	end,
})
