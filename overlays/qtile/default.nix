{... }:

final: prev:
{
  qtile = final.qtile.overrideAttrs(oldAttrs: {  
    pythonPath = oldAttrs.pythonPath ++ (with prev.python310Packages; [  
      qtile-extras
    ]);
  });  
}
