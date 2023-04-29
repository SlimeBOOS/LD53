-- Pick a color for text that would be approriate depending on the given
-- background color.
-- If background color is bright, returns black.
-- IF background color is dark, returns white.
return function(p1, p2, p3)
	local r, g, b
	if p1 and p2 and p3 then
		r, g, b = p1, p2, p3
	else
		r, g, b = p1[1], p1[2], p1[3]
	end
	if r+g+b < 1.5 then
		return 1, 1, 1, 1
	else
		return 0, 0, 0, 1
	end
end
