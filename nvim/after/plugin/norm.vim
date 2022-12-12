function! Norm()
	exe "! norminette | grep Err > _norm"
	exe "vs _norm"
endfunction
