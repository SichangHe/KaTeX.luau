-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/def.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
--@flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local ParseError = require(script.Parent.Parent.ParseError).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local globalMap = {
	["\\global"] = "\\global",
	["\\long"] = "\\\\globallong",
	["\\\\globallong"] = "\\\\globallong",
	["\\def"] = "\\gdef",
	["\\gdef"] = "\\gdef",
	["\\edef"] = "\\xdef",
	["\\xdef"] = "\\xdef",
	["\\let"] = "\\\\globallet",
	["\\futurelet"] = "\\\\globalfuture",
}
local function checkControlSequence(tok)
	local name = tok.text
	if Boolean.toJSBoolean(RegExp("^(?:[\\\\{}$&#^_]|EOF)$"):test(name)) then
		error(ParseError.new("Expected a control sequence", tok))
	end
	return name
end
local function getRHS(parser)
	local tok = parser.gullet:popToken()
	if tok.text == "=" then
		-- consume optional equals
		tok = parser.gullet:popToken()
		if tok.text == " " then
			-- consume one optional space
			tok = parser.gullet:popToken()
		end
	end
	return tok
end
local function letCommand(parser, name, tok, global)
	local macro = parser.gullet.macros:get(tok.text)
	if
		macro == nil --[[ ROBLOX CHECK: loose equality used upstream ]]
	then
		-- don't expand it later even if a macro with the same name is defined
		-- e.g., \let\foo=\frac \def\frac{\relax} \frac12
		tok.noexpand = true
		macro = {
			tokens = { tok },
			numArgs = 0,
			-- reproduce the same behavior in expansion
			unexpandable = not Boolean.toJSBoolean(parser.gullet:isExpandable(tok.text)),
		}
	end
	parser.gullet.macros:set(name, macro, global)
end -- <assignment> -> <non-macro assignment>|<macro assignment>
-- <non-macro assignment> -> <simple assignment>|\global<non-macro assignment>
-- <macro assignment> -> <definition>|<prefix><macro assignment>
-- <prefix> -> \global|\long|\outer
defineFunction({
	type = "internal",
	names = {
		"\\global",
		"\\long",
		"\\\\globallong", -- can’t be entered directly
	},
	props = { numArgs = 0, allowedInText = true },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		parser:consumeSpaces()
		local token = parser:fetch()
		if Boolean.toJSBoolean(globalMap[tostring(token.text)]) then
			-- KaTeX doesn't have \par, so ignore \long
			if funcName == "\\global" or funcName == "\\\\globallong" then
				token.text = globalMap[tostring(token.text)]
			end
			return assertNodeType(parser:parseFunction(), "internal")
		end
		error(ParseError.new("Invalid token after macro prefix", token))
	end,
}) -- Basic support for macro definitions: \def, \gdef, \edef, \xdef
-- <definition> -> <def><control sequence><definition text>
-- <def> -> \def|\gdef|\edef|\xdef
-- <definition text> -> <parameter text><left brace><balanced text><right brace>
defineFunction({
	type = "internal",
	names = { "\\def", "\\gdef", "\\edef", "\\xdef" },
	props = { numArgs = 0, allowedInText = true, primitive = true },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		local tok = parser.gullet:popToken()
		local name = tok.text
		if Boolean.toJSBoolean(RegExp("^(?:[\\\\{}$&#^_]|EOF)$"):test(name)) then
			error(ParseError.new("Expected a control sequence", tok))
		end
		local numArgs = 0
		local insert
		local delimiters = { {} } -- <parameter text> contains no braces
		while parser.gullet:future().text ~= "{" do
			tok = parser.gullet:popToken()
			if tok.text == "#" then
				-- If the very last character of the <parameter text> is #, so that
				-- this # is immediately followed by {, TeX will behave as if the {
				-- had been inserted at the right end of both the parameter text
				-- and the replacement text.
				if parser.gullet:future().text == "{" then
					insert = parser.gullet:future()
					table.insert(delimiters[tostring(numArgs)], "{") --[[ ROBLOX CHECK: check if 'delimiters[numArgs]' is an Array ]]
					break
				end -- A parameter, the first appearance of # must be followed by 1,
				-- the next by 2, and so on; up to nine #’s are allowed
				tok = parser.gullet:popToken()
				if not Boolean.toJSBoolean(RegExp("^[1-9]$"):test(tok.text)) then
					error(
						ParseError.new(('Invalid argument number "%s"'):format(tostring(tok.text)))
					)
				end
				if tonumber(tok.text) ~= numArgs + 1 then
					error(
						ParseError.new(
							('Argument number "%s" out of order'):format(tostring(tok.text))
						)
					)
				end
				numArgs += 1
				table.insert(delimiters, {}) --[[ ROBLOX CHECK: check if 'delimiters' is an Array ]]
			elseif tok.text == "EOF" then
				error(ParseError.new("Expected a macro definition"))
			else
				table.insert(delimiters[tostring(numArgs)], tok.text) --[[ ROBLOX CHECK: check if 'delimiters[numArgs]' is an Array ]]
			end
		end -- replacement text, enclosed in '{' and '}' and properly nested
		local tokens = parser.gullet:consumeArg().tokens
		if Boolean.toJSBoolean(insert) then
			table.insert(tokens, 1, insert) --[[ ROBLOX CHECK: check if 'tokens' is an Array ]]
		end
		if funcName == "\\edef" or funcName == "\\xdef" then
			tokens = parser.gullet:expandTokens(tokens)
			Array.reverse(tokens) --[[ ROBLOX CHECK: check if 'tokens' is an Array ]] -- to fit in with stack order
		end -- Final arg is the expansion of the macro
		parser.gullet.macros:set(
			name,
			{ tokens = tokens, numArgs = numArgs, delimiters = delimiters },
			funcName == globalMap[tostring(funcName)]
		)
		return { type = "internal", mode = parser.mode }
	end,
}) -- <simple assignment> -> <let assignment>
-- <let assignment> -> \futurelet<control sequence><token><token>
--     | \let<control sequence><equals><one optional space><token>
-- <equals> -> <optional spaces>|<optional spaces>=
defineFunction({
	type = "internal",
	names = {
		"\\let",
		"\\\\globallet", -- can’t be entered directly
	},
	props = { numArgs = 0, allowedInText = true, primitive = true },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		local name = checkControlSequence(parser.gullet:popToken())
		parser.gullet:consumeSpaces()
		local tok = getRHS(parser)
		letCommand(parser, name, tok, funcName == "\\\\globallet")
		return { type = "internal", mode = parser.mode }
	end,
}) -- ref: https://www.tug.org/TUGboat/tb09-3/tb22bechtolsheim.pdf
defineFunction({
	type = "internal",
	names = {
		"\\futurelet",
		"\\\\globalfuture", -- can’t be entered directly
	},
	props = { numArgs = 0, allowedInText = true, primitive = true },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		local name = checkControlSequence(parser.gullet:popToken())
		local middle = parser.gullet:popToken()
		local tok = parser.gullet:popToken()
		letCommand(parser, name, tok, funcName == "\\\\globalfuture")
		parser.gullet:pushToken(tok)
		parser.gullet:pushToken(middle)
		return { type = "internal", mode = parser.mode }
	end,
})
