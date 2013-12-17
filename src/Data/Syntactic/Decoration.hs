-- | Construct for decorating symbols or expressions with additional information

module Data.Syntactic.Decoration where



import Data.Tree

import Data.Syntactic.Syntax
import Data.Syntactic.Traversal
import Data.Syntactic.Constraint
import Data.Syntactic.Interpretation.Equality
import Data.Syntactic.Interpretation.Render
import Data.Syntactic.Interpretation.Evaluation
import Data.Syntactic.Interpretation.Semantics



-- | Decorating symbols or expressions with additional information
--
-- One usage of ':&:' is to decorate every node of a syntax tree. This is done
-- simply by changing
--
-- > AST sym sig
--
-- to
--
-- > AST (sym :&: info) sig
data (expr :&: info) sig
  where
    (:&:)
        :: { decorExpr :: expr sig
           , decorInfo :: info (DenResult sig)
           }
        -> (expr :&: info) sig

instance Constrained expr => Constrained (expr :&: info)
  where
    type Sat (expr :&: info) = Sat expr
    exprDict (a :&: _) = exprDict a

instance Project sub sup => Project sub (sup :&: info)
  where
    prj = prj . decorExpr

instance Equality expr => Equality (expr :&: info)
  where
    equal a b = decorExpr a `equal` decorExpr b
    exprHash  = exprHash . decorExpr

instance Render expr => Render (expr :&: info)
  where
    renderArgs args = renderArgs args . decorExpr
    render = render . decorExpr

instance ToTree expr => ToTree (expr :&: info)
  where
    toTreeArgs args = toTreeArgs args . decorExpr

instance Eval expr => Eval (expr :&: info)
  where
    evaluate = evaluate . decorExpr



-- | Get the decoration of the top-level node
getDecor :: AST (sym :&: info) sig -> info (DenResult sig)
getDecor (Sym (_ :&: info)) = info
getDecor (f :$ _)           = getDecor f

-- | Update the decoration of the top-level node
updateDecor :: forall info sym a .
    (info a -> info a) -> ASTF (sym :&: info) a -> ASTF (sym :&: info) a
updateDecor f = match update
  where
    update
        :: (a ~ DenResult sig)
        => (sym :&: info) sig
        -> Args (AST (sym :&: info)) sig
        -> ASTF (sym :&: info) a
    update (a :&: info) args = appArgs (Sym sym) args
      where
        sym = a :&: (f info)

-- | Lift a function that operates on expressions with associated information to
-- operate on a ':&:' expression. This function is convenient to use together
-- with e.g. 'queryNodeSimple' when the domain has the form @(sym `:&:` info)@.
liftDecor :: (expr s -> info (DenResult s) -> b) -> ((expr :&: info) s -> b)
liftDecor f (a :&: info) = f a info

-- | Strip decorations from an 'AST'
stripDecor :: AST (sym :&: info) sig -> AST sym sig
stripDecor (Sym (a :&: _)) = Sym a
stripDecor (f :$ a)        = stripDecor f :$ stripDecor a

-- | Rendering of decorated syntax trees
toTreeDecor :: forall info sym a . (Render info, ToTree sym) => ASTF (sym :&: info) a -> Tree String
toTreeDecor a = mkTree [] a
  where
    mkTree :: [Tree String] -> AST (sym :&: info) sig -> Tree String
    mkTree args (Sym (expr :&: info)) = Node infoStr [toTreeArgs args expr]
      where
        infoStr = "<" ++ render info ++ ">"
    mkTree args (f :$ a) = mkTree (mkTree [] a : args) f

-- | Show an decorated syntax tree using ASCII art
showDecor :: (Render info, ToTree sym) => ASTF (sym :&: info) a -> String
showDecor = drawTree . toTreeDecor

-- | Print an decorated syntax tree using ASCII art
drawDecor :: (Render info, ToTree sym) => ASTF (sym :&: info) a -> IO ()
drawDecor = putStrLn . showDecor
