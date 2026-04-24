{-# LANGUAGE BangPatterns     #-}
{-# LANGUAGE TemplateHaskell  #-}
{-# LANGUAGE TupleSections    #-}
-- FIXME: better types in checkLevel
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DeriveGeneric    #-}
{-# LANGUAGE DeriveAnyClass   #-}
-- |
-- Copyright   : (c) 2010-2012 Simon Meier & Benedikt Schmidt
-- License     : GPL v3 (see LICENSE)
--
-- Portability : GHC only
--
-- Types to represent proofs.
module Theory.Proof (
  -- * Utilities
    LTree(..)
  , mergeMapsWith

  -- * Types
  , ProofStep(..)
  , DiffProofStep(..)
  , Proof
  , DiffProof

  -- ** Paths inside proofs
  , ProofPath
  , atPath
  , atPathDiff
  , modifyAtPath
  , insertPaths
  , insertPathsDiff

  -- ** Folding/modifying proofs
  , mapProofInfo
  , mapDiffProofInfo
  , foldProof
  , foldDiffProof
  , annotateProof
  , annotateDiffProof
  , ProofStatus(..)
  , proofStepStatus
  , diffProofStepStatus

  -- ** Unfinished proofs
  , sorry
  , unproven
  , unprovenLookAhead
  , diffSorry
  , diffUnproven

  , selectHeuristic
  , selectDiffHeuristic
  , selectTactic
  , selectDiffTactic

  -- ** Incremental proof construction
  , IncrementalProof
  , IncrementalDiffProof
  , Prover
  , DiffProver
  , runProver
  , runDiffProver
  , mapProverProof
  , mapDiffProverDiffProof

  , orelse
  , tryProver
  , sorryProver
  , sorryDiffProver
  , oneStepProver
  , oneStepDiffProver
  , focus
  , focusDiff
  , checkAndExtendProver
  , checkAndExtendDiffProver
  , checkProof
  , replaceSorryProver
  , replaceDiffSorryProver
  , contradictionProver
  , contradictionDiffProver

  -- ** Explicit representation of a fully automatic prover
  , SolutionExtractor(..)
  , AutoProver(..)
  , runAutoProver
  , runAutoDiffProver

  -- ** Pretty Printing
  , prettyProof
  , prettyDiffProof
  , prettyProofWith
  , prettyDiffProofWith

  , showProofStatus
  , showDiffProofStatus

  -- ** Parallel Strategy for exploring a proof
  , parLTreeDFS

  -- ** Small-step interface to the constraint solver
  , module Theory.Constraint.Solver

) where

import           GHC.Generics                     (Generic)

import           Data.Binary
import           Data.List
import qualified Data.Label                       as L
import qualified Data.Map                         as M
import           Data.Maybe
-- import           Data.Monoid

import           Debug.Trace

import           Control.Basics
import           Control.DeepSeq
import qualified Control.Monad.State              as S
import           Control.Parallel.Strategies

import           Theory.Constraint.Solver
import           Theory.Model
import           Theory.Text.Pretty

import System.Random (StdGen,mkStdGen,randomR,split)
import           System.IO.Unsafe
import GHC.Float (int2Double, float2Int, int2Float, double2Int)



------------------------------------------------------------------------------
-- Utility: Trees with uniquely labelled edges.
------------------------------------------------------------------------------

-- | Trees with uniquely labelled edges.
data LTree l a = LNode
     { root     :: a
     , children :: M.Map l (LTree l a)
     }
     deriving( Eq, Ord, Show )

instance Functor (LTree l) where
    fmap f (LNode r cs) = LNode (f r) (M.map (fmap f) cs)

instance Foldable (LTree l) where
    foldMap f (LNode x cs) = f x `mappend` foldMap (foldMap f) cs

instance Traversable (LTree l) where
    traverse f (LNode x cs) = LNode <$> f x <*> traverse (traverse f) cs

-- | A parallel evaluation strategy well-suited for DFS traversal: As soon as
-- a node is forced it sparks off the computation of the number of case-maps
-- of all its children. This way most of the data is already evaulated, when
-- the actual DFS traversal visits it.
--
-- NOT used for now. It sometimes required too much memory.
parLTreeDFS :: Strategy (LTree l a)
parLTreeDFS (LNode x0 cs0) = do
    cs0' <- (`parTraversable` cs0) $ \(LNode x cs) -> LNode x <$> rseq cs
    return $ LNode x0 (M.map (runEval . parLTreeDFS) cs0')

------------------------------------------------------------------------------
-- Utility: Merging maps
------------------------------------------------------------------------------

-- | /O(n+m)/. A generalized union operator for maps with differing types.
mergeMapsWith :: Ord k
              => (a -> c) -> (b -> c) -> (a -> b -> c)
              -> M.Map k a -> M.Map k b -> M.Map k c
mergeMapsWith leftOnly rightOnly combine l r =
    M.map extract $ M.unionWith combine' l' r'
  where
    l' = M.map (Left . Left)  l
    r' = M.map (Left . Right) r

    combine' (Left (Left a)) (Left (Right b)) = Right $ combine a b
    combine' _ _ = error "mergeMapsWith: impossible"

    extract (Left (Left  a)) = leftOnly  a
    extract (Left (Right b)) = rightOnly b
    extract (Right c)        = c


------------------------------------------------------------------------------
-- Proof Steps
------------------------------------------------------------------------------

-- | A proof steps is a proof method together with additional context-dependent
-- information.
data ProofStep a = ProofStep
     { psMethod :: ProofMethod
     , psBlackList :: [Maybe Goal]
     , psInfo   :: a
     }
     deriving( Eq, Ord, Show, Generic, NFData, Binary )

instance Functor ProofStep where
    fmap f (ProofStep m bl i) = ProofStep m bl (f i)

instance Foldable ProofStep where
    foldMap f = f . psInfo

instance Traversable ProofStep where
    traverse f (ProofStep m bl i) = ProofStep m bl <$> f i

instance HasFrees a => HasFrees (ProofStep a) where
    foldFrees f (ProofStep m bl i) = foldFrees f m `mappend` foldFrees f bl `mappend` foldFrees f i
    foldFreesOcc  _ _ = const mempty
    mapFrees f (ProofStep m bl i)  = ProofStep <$> mapFrees f m  <*> mapFrees f bl <*> mapFrees f i

-- | A diff proof steps is a proof method together with additional context-dependent
-- information.
data DiffProofStep a = DiffProofStep
     { dpsMethod :: DiffProofMethod
     , dpsInfo   :: a
     }
     deriving( Eq, Ord, Show, Generic, NFData, Binary )

instance Functor DiffProofStep where
    fmap f (DiffProofStep m i) = DiffProofStep m (f i)

instance Foldable DiffProofStep where
    foldMap f = f . dpsInfo

instance Traversable DiffProofStep where
    traverse f (DiffProofStep m i) = DiffProofStep m <$> f i

instance HasFrees a => HasFrees (DiffProofStep a) where
    foldFrees f (DiffProofStep m i) = foldFrees f m `mappend` foldFrees f i
    foldFreesOcc  _ _ = const mempty
    mapFrees f (DiffProofStep m i)  = DiffProofStep <$> mapFrees f m <*> mapFrees f i


------------------------------------------------------------------------------
-- Proof Trees
------------------------------------------------------------------------------

-- | A path to a subproof.
type ProofPath = [CaseName]

-- | A proof is a tree of proof steps whose edges are labelled with case names.
type Proof a = LTree CaseName (ProofStep a)

-- | A diff proof is a tree of proof steps whose edges are labelled with case names.
type DiffProof a = LTree CaseName (DiffProofStep a)

-- Unfinished proofs
--------------------

-- | A proof using the 'sorry' proof method.
sorry :: Maybe String -> [Maybe Goal] -> a -> Proof a
sorry reason bl ann = LNode (ProofStep (Sorry reason) bl ann) M.empty

-- | A proof using the 'sorry' proof method.
diffSorry :: Maybe String -> a -> DiffProof a
diffSorry reason ann = LNode (DiffProofStep (DiffSorry reason) ann) M.empty

-- | A proof denoting an unproven part of the proof.
unproven :: a -> Proof a
unproven = sorry Nothing []

-- | A proof denoting an unproven part of the proof.
unprovenLookAhead :: ProofContext -> [Maybe Goal] -> System -> IncrementalProof
unprovenLookAhead ctxt blacklist sys = maybe (sorry Nothing blacklist (Just sys)) toNode (isFinished ctxt sys)
  where
    toNode :: Result -> IncrementalProof
    toNode r = LNode (ProofStep (Finished r) blacklist (Just sys)) M.empty

-- | A proof denoting an unproven part of the proof.
diffUnproven :: a -> DiffProof a
diffUnproven = diffSorry Nothing

-- Paths in proofs
------------------

-- | @prf `atPath` path@ returns the subproof at the @path@ in @prf@.
atPath :: Proof a -> ProofPath -> Maybe (Proof a)
atPath = foldM (flip M.lookup . children)

-- | @prf `atPath` path@ returns the subproof at the @path@ in @prf@.
atPathDiff :: DiffProof a -> ProofPath -> Maybe (DiffProof a)
atPathDiff = foldM (flip M.lookup . children)

-- | @modifyAtPath f path prf@ applies @f@ to the subproof at @path@,
-- if there is one.
modifyAtPath :: (Proof a -> Maybe (Proof a)) -> ProofPath
             -> Proof a -> Maybe (Proof a)
modifyAtPath f =
    go
  where
    go []     prf = f prf
    go (l:ls) prf = do
        let cs = children prf
        prf' <- go ls =<< M.lookup l cs
        return (prf { children = M.insert l prf' cs })

-- | @modifyAtPath f path prf@ applies @f@ to the subproof at @path@,
-- if there is one.
modifyAtPathDiff :: (DiffProof a -> Maybe (DiffProof a)) -> ProofPath
                 -> DiffProof a -> Maybe (DiffProof a)
modifyAtPathDiff f =
    go
  where
    go []     prf = f prf
    go (l:ls) prf = do
        let cs = children prf
        prf' <- go ls =<< M.lookup l cs
        return (prf { children = M.insert l prf' cs })

-- | @insertPaths prf@ inserts the path to every proof node.
insertPaths :: Proof a -> Proof (a, ProofPath)
insertPaths =
    insertPath []
  where
    insertPath path (LNode ps cs) =
        LNode (fmap (,reverse path) ps)
              (M.mapWithKey (\n prf -> insertPath (n:path) prf) cs)

-- | @insertPaths prf@ inserts the path to every diff proof node.
insertPathsDiff :: DiffProof a -> DiffProof (a, ProofPath)
insertPathsDiff =
    insertPath []
  where
    insertPath path (LNode ps cs) =
        LNode (fmap (,reverse path) ps)
              (M.mapWithKey (\n prf -> insertPath (n:path) prf) cs)

-- Utilities for dealing with proofs
------------------------------------


-- | Apply a function to the information of every proof step.
mapProofInfo :: (a -> b) -> Proof a -> Proof b
mapProofInfo = fmap . fmap

-- | Apply a function to the information of every proof step.
mapDiffProofInfo :: (a -> b) -> DiffProof a -> DiffProof b
mapDiffProofInfo = fmap . fmap

-- | @boundProofDepth bound prf@ bounds the depth of the proof @prf@ using
-- 'Sorry' steps to replace the cut sub-proofs.
boundProofDepth :: Int -> Proof a -> Proof a
boundProofDepth bound =
    go bound
  where
    go n (LNode ps@(ProofStep _ bl info) cs)
      | 0 < n     = LNode ps                     $ M.map (go (pred n)) cs
      | otherwise = sorry (Just $ "bound " ++ show bound ++ " hit") bl info

-- | @boundProofDepth bound prf@ bounds the depth of the proof @prf@ using
-- 'Sorry' steps to replace the cut sub-proofs.
boundDiffProofDepth :: Int -> DiffProof a -> DiffProof a
boundDiffProofDepth bound =
    go bound
  where
    go n (LNode ps@(DiffProofStep _ info) cs)
      | 0 < n     = LNode ps                     $ M.map (go (pred n)) cs
      | otherwise = diffSorry (Just $ "bound " ++ show bound ++ " hit") info


-- | Fold a proof.
foldProof :: Monoid m => (ProofStep a -> m) -> Proof a -> m
foldProof f =
    go
  where
    go (LNode step cs) = f step `mappend` foldMap go (M.elems cs)

-- | Fold a proof.
foldDiffProof :: Monoid m => (DiffProofStep a -> m) -> DiffProof a -> m
foldDiffProof f =
    go
  where
    go (LNode step cs) = f step `mappend` foldMap go (M.elems cs)

-- | Annotate a proof in a bottom-up fashion.
annotateProof :: (ProofStep a -> [b] -> b) -> Proof a -> Proof b
annotateProof f =
    go
  where
    go (LNode step@(ProofStep method bl _) cs) =
        LNode (ProofStep method bl info') cs'
      where
        cs' = M.map go cs
        info' = f step (map (psInfo . root . snd) (M.toList cs'))

-- | Annotate a proof in a bottom-up fashion.
annotateDiffProof :: (DiffProofStep a -> [b] -> b) -> DiffProof a -> DiffProof b
annotateDiffProof f =
    go
  where
    go (LNode step@(DiffProofStep method _) cs) =
        LNode (DiffProofStep method info') cs'
      where
        cs' = M.map go cs
        info' = f step (map (dpsInfo . root . snd) (M.toList cs'))

-- Proof cutting
----------------

-- | The status of a 'Proof'.
data ProofStatus =
         UndeterminedProof  -- ^ All steps are unannotated
       | CompleteProof      -- ^ The proof is complete: no annotated sorry,
                            --  no annotated solved step
       | IncompleteProof    -- ^ There is a annotated sorry,
                            --   but no annotated solved step.
       | TraceFound         -- ^ There is an annotated solved step
       | UnfinishableProof  -- ^ The proof cannot be finished (due to reducible operators in subterms)
                            --   i.e. all ends are either Completed or Unfinishable (if a trace is found, then the status is TraceFound)
       | InvalidatedProof   -- ^ The proof has been Invalidated (eg. by editing a reuse lemma)
    deriving ( Show, Generic, NFData, Binary, Eq )

instance Semigroup ProofStatus where
    InvalidatedProof <> _                  = InvalidatedProof
    _ <> InvalidatedProof                  = InvalidatedProof
    TraceFound <> _                        = TraceFound
    _ <> TraceFound                        = TraceFound
    IncompleteProof <> _                   = IncompleteProof
    _ <> IncompleteProof                   = IncompleteProof
    UnfinishableProof <> _                 = UnfinishableProof
    _ <> UnfinishableProof                 = UnfinishableProof
    CompleteProof <> _                     = CompleteProof
    _ <> CompleteProof                     = CompleteProof
    UndeterminedProof <> UndeterminedProof = UndeterminedProof


instance Monoid ProofStatus where
    mempty = CompleteProof

-- | The status of a 'ProofStep'.
proofStepStatus :: ProofStep (Maybe a) -> ProofStatus
proofStepStatus (ProofStep _ _                          Nothing ) = UndeterminedProof
proofStepStatus (ProofStep (Finished Solved) _           (Just _)) = TraceFound
proofStepStatus (ProofStep (Finished (Unfinishable _)) _ (Just _)) = UnfinishableProof
proofStepStatus (ProofStep (Finished Stopped) _          (Just _)) = IncompleteProof
proofStepStatus (ProofStep (Sorry _)  _  (Just _)) = IncompleteProof
proofStepStatus (ProofStep Invalidated _ (Just _)) = InvalidatedProof
proofStepStatus (ProofStep _ _           (Just _)) = CompleteProof

-- | The status of a 'DiffProofStep'.
diffProofStepStatus :: DiffProofStep (Maybe a) -> ProofStatus
diffProofStepStatus (DiffProofStep _                Nothing ) = UndeterminedProof
diffProofStepStatus (DiffProofStep DiffAttack       (Just _)) = TraceFound
diffProofStepStatus (DiffProofStep (DiffSorry _)    (Just _)) = IncompleteProof
diffProofStepStatus (DiffProofStep DiffUnfinishable (Just _)) = UnfinishableProof
diffProofStepStatus (DiffProofStep _                (Just _)) = CompleteProof

-- | @checkProof rules se prf@ replays the proof @prf@ against the start
-- sequent @se@. A failure to apply a proof method is denoted by a resulting
-- proof step without an annotated sequent. An unhandled case is denoted using
-- the 'Sorry' proof method.
checkProof :: ProofContext
           -> (Int -> System -> Proof (Maybe System)) -- prover for new cases in depth
           -> Int         -- ^ Original depth
           -> System
           -> Proof a
           -> Proof (Maybe a, Maybe System)
checkProof ctxt prover =
    go
  where
    go d sys prf@(LNode (ProofStep method bl info) cs) = case (method, checkAndExecProofMethod ctxt method sys) of
      (Sorry reason, _         ) -> sorryNode reason bl cs
      (_           , Just cases) -> node method bl $ checkChildren cases
      (_           , Nothing   ) -> sorryNode (Just "invalid proof step encountered") bl
                                      (M.singleton "" prf)
      where
        unhandledCase = mapProofInfo (Nothing,) . prover d
        checkChildren cases = mergeMapsWith unhandledCase noSystemPrf (go (d + 1)) cases cs

        node m bl              = LNode (ProofStep m bl (Just info, Just sys))
        sorryNode reason bl cases = node (Sorry reason) bl (M.map noSystemPrf cases)
        noSystemPrf            = mapProofInfo (\i -> (Just i, Nothing))

-- | @checkDiffProof rules se prf@ replays the proof @prf@ against the start
-- sequent @se@. A failure to apply a proof method is denoted by a resulting
-- proof step without an annotated sequent. An unhandled case is denoted using
-- the 'Sorry' proof method.
checkDiffProof :: DiffProofContext
           -> (Int -> DiffSystem -> DiffProof (Maybe DiffSystem)) -- prover for new cases in depth
           -> Int         -- ^ Original depth
           -> DiffSystem
           -> DiffProof a
           -> DiffProof (Maybe a, Maybe DiffSystem)
checkDiffProof ctxt prover =
    go
  where
    go d s prf@(LNode (DiffProofStep method info) cs) = case (method, execDiffProofMethod ctxt method s) of
      (DiffSorry reason, _         ) -> sorryNode reason cs
      (_               , Just cases) -> node method $ checkChildren cases
      (_               , Nothing   ) ->
          sorryNode (Just "invalid proof step encountered")
                    (M.singleton "" prf)
      where
        unhandledCase = mapDiffProofInfo (Nothing,) . prover d
        checkChildren cases = mergeMapsWith unhandledCase noSystemPrf (go (d + 1)) cases cs

        node m                 = LNode (DiffProofStep m (Just info, Just s))
        sorryNode reason cases = node (DiffSorry reason) (M.map noSystemPrf cases)
        noSystemPrf            = mapDiffProofInfo (\i -> (Just i, Nothing))

------------------------------------------------------------------------------
-- Provers: the interface to the outside world.
------------------------------------------------------------------------------

-- | Incremental proofs are used to represent intermediate results of proof
-- checking/construction.
type IncrementalProof = Proof (Maybe System)

-- | Incremental diff proofs are used to represent intermediate results of proof
-- checking/construction.
type IncrementalDiffProof = DiffProof (Maybe DiffSystem)


-- | Provers whose sequencing is handled via the 'Monoid' instance.
--
-- > p1 `mappend` p2
--
-- Is a prover that first runs p1 and then p2 on the resulting proof.
newtype Prover =  Prover
          { runProver
              :: ProofContext              -- proof rules to use
              -> Int                       -- proof depth
              -> System                    -- original sequent to start with
              -> IncrementalProof          -- original proof
              -> Maybe IncrementalProof    -- resulting proof
          }

instance Semigroup Prover where
    p1 <> p2 = Prover $ \ctxt d se ->
        runProver p1 ctxt d se >=> runProver p2 ctxt d se

instance Monoid Prover where
    mempty          = Prover $ \_  _ _ -> Just

-- | Provers whose sequencing is handled via the 'Monoid' instance.
--
-- > p1 `mappend` p2
--
-- Is a prover that first runs p1 and then p2 on the resulting proof.
newtype DiffProver =  DiffProver
          { runDiffProver
              :: DiffProofContext              -- proof rules to use
              -> Int                           -- proof depth
              -> DiffSystem                    -- original sequent to start with
              -> IncrementalDiffProof          -- original proof
              -> Maybe IncrementalDiffProof    -- resulting proof
          }

instance Semigroup DiffProver where
    p1 <> p2 = DiffProver $ \ctxt d se ->
        runDiffProver p1 ctxt d se >=> runDiffProver p2 ctxt d se

instance Monoid DiffProver where
    mempty          = DiffProver $ \_  _ _ -> Just

-- | Map the proof generated by the prover.
mapProverProof :: (IncrementalProof -> IncrementalProof) -> Prover -> Prover
mapProverProof f p = Prover $ \ ctxt d se prf -> f <$> runProver p ctxt d se prf

-- | Map the proof generated by the prover.
mapDiffProverDiffProof :: (IncrementalDiffProof -> IncrementalDiffProof) -> DiffProver -> DiffProver
mapDiffProverDiffProof f p = DiffProver $ \ctxt d se prf -> f <$> runDiffProver p ctxt d se prf

-- | Prover that always fails.
failProver :: Prover
failProver = Prover (\ _ _ _ _ -> Nothing)

-- | Prover that always fails.
failDiffProver :: DiffProver
failDiffProver = DiffProver (\_ _ _ _ -> Nothing)

-- | Resorts to the second prover, if the first one is not successful.
orelse :: Prover -> Prover -> Prover
orelse p1 p2 = Prover $ \ctxt d se prf ->
    runProver p1 ctxt d se prf `mplus` runProver p2 ctxt d se prf

-- | Resorts to the second prover, if the first one is not successful.
orelseDiff :: DiffProver -> DiffProver -> DiffProver
orelseDiff p1 p2 = DiffProver $ \ctxt d se prf ->
    runDiffProver p1 ctxt d se prf `mplus` runDiffProver p2 ctxt d se prf

-- | Try to apply a prover. If it fails, just return the original proof.
tryProver :: Prover -> Prover
tryProver =  (`orelse` mempty)

-- | Try to execute one proof step using the given proof method.
oneStepProver :: [Maybe Goal] -> ProofMethod -> Prover
oneStepProver blacklist method = Prover $ \ctxt _ se _ -> do
    cases <- execProofMethod ctxt method se
    return $ LNode (ProofStep method blacklist (Just se)) (M.map (unprovenLookAhead ctxt blacklist) cases)

-- | Try to execute one proof step using the given proof method.
oneStepDiffProver :: DiffProofMethod -> DiffProver
oneStepDiffProver method = DiffProver $ \ctxt _ se _ -> do
    cases <- execDiffProofMethod ctxt method se
    return $ LNode (DiffProofStep method (Just se)) (M.map (diffUnproven . Just) cases)

-- | Replace the current proof with a sorry step and the given reason.
sorryProver :: Maybe String -> [Maybe Goal] -> Prover
sorryProver reason bl = Prover $ \_ _ se _ -> return $ sorry reason bl (Just se)

-- | Replace the current proof with a sorry step and the given reason.
sorryDiffProver :: Maybe String -> DiffProver
sorryDiffProver reason = DiffProver $ \_ _ se _ -> return $ diffSorry reason (Just se)

-- | Apply a prover only to a sub-proof, fails if the subproof doesn't exist.
focus :: ProofPath -> Prover -> Prover
focus []   prover = prover
focus path prover =
    Prover $ \ctxt d _ prf ->
        modifyAtPath (prover' ctxt (d + length path)) path prf
  where
    prover' ctxt d prf = do
        se <- psInfo (root prf)
        runProver prover ctxt d se prf

-- | Apply a diff prover only to a sub-proof, fails if the subproof doesn't exist.
focusDiff :: ProofPath -> DiffProver -> DiffProver
focusDiff []   prover = prover
focusDiff path prover =
    DiffProver $ \ctxt d _ prf ->
        modifyAtPathDiff (prover' ctxt (d + length path)) path prf
  where
    prover' ctxt d prf = do
        se <- dpsInfo (root prf)
        runDiffProver prover ctxt d se prf

-- | Check the proof and handle new cases using the given prover.
checkAndExtendProver :: Prover -> Prover
checkAndExtendProver prover0 = Prover $ \ctxt d se prf ->
    return $ mapProofInfo snd $ checkProof ctxt (prover ctxt) d se prf
  where
    unhandledCase   = sorry (Just "unhandled case") [] Nothing
    prover ctxt d se =
        fromMaybe unhandledCase $ runProver prover0 ctxt d se unhandledCase

-- | Check the proof and handle new cases using the given prover.
checkAndExtendDiffProver :: DiffProver -> DiffProver
checkAndExtendDiffProver prover0 = DiffProver $ \ctxt d se prf ->
    return $ mapDiffProofInfo snd $ checkDiffProof ctxt (prover ctxt) d se prf
  where
    unhandledCase = diffSorry (Just "unhandled case") Nothing
    prover ctxt d se =
        fromMaybe unhandledCase $ runDiffProver prover0 ctxt d se unhandledCase

-- | Replace all annotated sorry steps using the given prover.
replaceSorryProver :: Prover -> Prover
replaceSorryProver prover0 = Prover prover
  where
    prover ctxt d _ = return . replace
      where
        replace prf@(LNode (ProofStep (Sorry _) _ (Just se)) _) =
            fromMaybe prf $ runProver prover0 ctxt d se prf
        replace (LNode ps cases) =
            LNode ps $ M.map replace cases

-- | Replace all annotated sorry steps using the given prover.
replaceDiffSorryProver :: DiffProver -> DiffProver
replaceDiffSorryProver prover0 = DiffProver prover
  where
    prover ctxt d _ = return . replace
      where
        replace prf@(LNode (DiffProofStep (DiffSorry _) (Just se)) _) =
            fromMaybe prf $ runDiffProver prover0 ctxt d se prf
        replace (LNode ps cases) =
            LNode ps $ M.map replace cases

-- | Use the first prover that works.
firstProver :: [Prover] -> Prover
firstProver = foldr orelse failProver

-- | Prover that does one contradiction step.
contradictionProver :: Prover
contradictionProver = Prover $ \ctxt d sys prf ->
    runProver
        (firstProver $ map (oneStepProver [])
            (Finished . Contradictory . Just <$> contradictions ctxt sys))
        ctxt d sys prf

-- | Use the first diff prover that works.
firstDiffProver :: [DiffProver] -> DiffProver
firstDiffProver = foldr orelseDiff failDiffProver

-- | Diff Prover that does one contradiction step if possible.
contradictionDiffProver :: DiffProver
contradictionDiffProver = DiffProver $ \ctxt d sys prf ->
  case (L.get dsCurrentRule sys, L.get dsSide sys, L.get dsSystem sys) of
    (Just _, Just s, Just sys') -> runDiffProver
              (firstDiffProver $ map oneStepDiffProver $
                  (DiffBackwardSearchStep . Finished . Contradictory . Just <$> contradictions (eitherProofContext ctxt s) sys'))
          ctxt d sys prf
    (_     , _     , _        ) -> Nothing

------------------------------------------------------------------------------
-- Automatic Prover's
------------------------------------------------------------------------------

data SolutionExtractor = CutDFS | CutBFS | CutSingleThreadDFS | CutNothing | CutAfterSorry
    deriving( Eq, Ord, Show, Read, Generic, NFData, Binary )

data AutoProver = AutoProver
    { apDefaultHeuristic :: Maybe (Heuristic ProofContext)
    , apDefaultTactic   :: Maybe [Tactic ProofContext]
    , apDefaultStrategy :: Maybe AutomatedProofStrategy
    , apSeed            :: Maybe StdGen
    , apBound            :: Maybe Int
    , apCut              :: SolutionExtractor
    , quitOnEmptyOracle  :: Bool
    , apExportGoals       :: Bool
    }
    deriving ( Generic, NFData, Binary )

selectHeuristic :: AutoProver -> ProofContext -> Heuristic ProofContext
selectHeuristic prover ctx = setQuitOnEmpty $ fromMaybe (defaultHeuristic False)
                             (apDefaultHeuristic prover <|> L.get pcHeuristic ctx)
  where
    setQuitOnEmpty :: Heuristic ProofContext -> Heuristic ProofContext
    setQuitOnEmpty (Heuristic rankings) = Heuristic (map aux rankings)

    aux :: GoalRanking a -> GoalRanking a
    aux (OracleRanking _ o) = OracleRanking (quitOnEmptyOracle prover) o
    aux (OracleSmartRanking _ o) = OracleSmartRanking (quitOnEmptyOracle prover) o
    aux (InternalTacticRanking _ t) = InternalTacticRanking (quitOnEmptyOracle prover) t
    aux gr = gr

selectDiffHeuristic :: AutoProver -> DiffProofContext -> Heuristic ProofContext
selectDiffHeuristic prover ctx = fromMaybe (defaultHeuristic True)
                                 (apDefaultHeuristic prover <|> L.get pcHeuristic (L.get dpcPCLeft ctx))

selectTactic :: AutoProver -> ProofContext -> [Tactic ProofContext]
selectTactic prover ctx = fromMaybe [defaultTactic]
                             (apDefaultTactic prover <|> L.get pcTactic ctx)

selectDiffTactic :: AutoProver -> DiffProofContext -> [Tactic ProofContext]
selectDiffTactic prover ctx = fromMaybe [defaultTactic]
                                 (apDefaultTactic prover <|> L.get pcTactic (L.get dpcPCLeft ctx))

selectProofStrategy :: AutoProver -> ProofContext -> AutomatedProofStrategy
selectProofStrategy prover ctxt = setSeedAutoStrategy (selectSeed prover ctxt) strat
            where 
              strat = fromMaybe Original
                                      (apDefaultStrategy prover <|> L.get pcAutomatedProofStrat ctxt)

selectExportGoals :: AutoProver -> ProofContext -> Bool
selectExportGoals prover ctx = apExportGoals prover || L.get pcExportGoals ctx

selectSeed :: AutoProver -> ProofContext -> StdGen
selectSeed prover ctx = fromMaybe (mkStdGen 0)
                             (apSeed prover <|> L.get pcSeed ctx)

runAutoProver :: AutoProver -> Prover
runAutoProver aut@(AutoProver _ _ _ _ bound cut _ _) =
    mapProverProof cutSolved $ maybe id boundProver bound autoProver
  where
    cutSolved = case cut of
      CutDFS             -> cutOnSolvedDFS
      CutBFS             -> cutOnSolvedBFS
      CutSingleThreadDFS -> cutOnSolvedSingleThreadDFS
      CutNothing         -> id
      CutAfterSorry      -> cutAfterFirstSorry

    -- | The standard automatic prover that ignores the existing proof and
    -- tries to find one by itself.
    autoProver :: Prover
    autoProver = Prover $ \ctxt depth sysPath _ -> return $ proof ctxt depth sysPath []
      where 
        proof cx d s skL = case proveSystemDFS (selectExportGoals aut cx) (selectProofStrategy aut cx) (selectHeuristic aut cx) (selectTactic aut cx) cx d s skL of
            LNode (ProofStep (Finished (Unfinishable [])) _ info) c -> LNode (ProofStep (Finished (Unfinishable [])) [] info) c
            LNode (ProofStep (Finished (Unfinishable sL)) _ _) _ -> proof cx d s sL
            node -> node
        -- return $ 
        -- proveSystemDFS (selectProofStrategy aut ctxt) (selectHeuristic aut ctxt) (selectTactic aut ctxt) ctxt depth sysPath

    -- | Bound the depth of proofs generated by the given prover.
    boundProver :: Int -> Prover -> Prover
    boundProver b p = Prover $ \ctxt d se prf ->
        boundProofDepth b <$> runProver p ctxt d se prf

runAutoDiffProver :: AutoProver -> DiffProver
runAutoDiffProver aut@(AutoProver _ _ _ _ bound cut _ _) =
    mapDiffProverDiffProof cutSolved $ maybe id boundProver bound autoProver
  where
    cutSolved = case cut of
      CutDFS             -> cutOnSolvedDFSDiff
      CutBFS             -> cutOnSolvedBFSDiff
      CutSingleThreadDFS -> cutOnSolvedSingleThreadDFSDiff
      CutAfterSorry      -> cutAfterFirstSorryDiff
      CutNothing         -> id

    -- | The standard automatic prover that ignores the existing proof and
    -- tries to find one by itself.
    autoProver :: DiffProver
    autoProver = DiffProver $ \ctxt depth syss _ ->
        return $ proveDiffSystemDFS (selectDiffHeuristic aut ctxt) (selectDiffTactic aut ctxt) ctxt depth syss

    -- | Bound the depth of proofs generated by the given prover.
    boundProver :: Int -> DiffProver -> DiffProver
    boundProver b p = DiffProver $ \ctxt d se prf ->
        boundDiffProofDepth b <$> runDiffProver p ctxt d se prf


-- | The result of one pass of iterative deepening.
data IterDeepRes = NoSolution | MaybeNoSolution | Solution ProofPath

instance Semigroup IterDeepRes where
    x@(Solution _)   <> _                = x
    _                <> y@(Solution _)   = y
    MaybeNoSolution  <> _                = MaybeNoSolution
    _                <> MaybeNoSolution  = MaybeNoSolution
    NoSolution       <> NoSolution       = NoSolution

instance Monoid IterDeepRes where
    mempty = NoSolution

-- | @cutOnSolvedSingleThreadDFS prf@ removes all other cases if an attack is
-- found. The attack search is performed using a single-thread DFS traversal.
--
-- FIXME: Note that this function may use a lot of space, as it holds onto the
-- whole proof tree.
cutOnSolvedSingleThreadDFS :: Proof (Maybe a) -> Proof (Maybe a)
cutOnSolvedSingleThreadDFS prf0 =
    go $ insertPaths prf0
  where
    go prf = case findSolved prf of
        NoSolution      -> prf0
        Solution path   -> extractSolved path prf0
        MaybeNoSolution -> error "Theory.Constraint.cutOnSolvedSingleThreadDFS: impossible, MaybeNoSolution in single thread dfs"
      where
        findSolved node = case node of
              -- do not search in nodes that are not annotated
              LNode (ProofStep _ _     (Nothing, _   )) _  -> NoSolution
              LNode (ProofStep (Finished Solved) _ (Just _ , path)) _  -> Solution path
              LNode (ProofStep _ _     (Just _ , _   )) cs ->
                  foldMap findSolved cs

    extractSolved []         p               = p
    extractSolved (label:ps) (LNode pstep m) = case M.lookup label m of
        Just subprf ->
          LNode pstep (M.fromList [(label, extractSolved ps subprf)])
        Nothing     ->
          error "Theory.Constraint.cutOnSolvedSingleThreadDFS: impossible, extractSolved failed, invalid path"

-- | @cutOnSolvedSingleThreadDFSDiffDFS prf@ removes all other cases if an
-- attack is found. The attack search is performed using a single-thread DFS
-- traversal.
--
-- FIXME: Note that this function may use a lot of space, as it holds onto the
-- whole proof tree.
cutOnSolvedSingleThreadDFSDiff :: DiffProof (Maybe a) -> DiffProof (Maybe a)
cutOnSolvedSingleThreadDFSDiff prf0 =
    go $ insertPathsDiff prf0
  where
    go prf = case findSolved prf of
        NoSolution      -> prf0
        Solution path   -> extractSolved path prf0
        MaybeNoSolution -> error "Theory.Constraint.cutOnSolvedSingleThreadDFSDiff: impossible, MaybeNoSolution in single thread dfs"
      where
        findSolved node = case node of
              -- do not search in nodes that are not annotated
              LNode (DiffProofStep _      (Nothing, _   )) _  -> NoSolution
              LNode (DiffProofStep DiffAttack (Just _ , path)) _  -> Solution path
              LNode (DiffProofStep _      (Just _ , _   )) cs ->
                  foldMap findSolved cs

    extractSolved []         p               = p
    extractSolved (label:ps) (LNode pstep m) = case M.lookup label m of
        Just subprf ->
          LNode pstep (M.fromList [(label, extractSolved ps subprf)])
        Nothing     ->
          error "Theory.Constraint.cutOnSolvedSingleThreadDFSDiff: impossible, extractSolved failed, invalid path"

-- | @cutOnSolvedDFS prf@ removes all other cases if an attack is found. The
-- attack search is performed using a parallel DFS traversal with iterative
-- deepening.
-- Note that when an attack is found, other, already started threads will not be
-- stopped. They will first run to completion, and only afterwards will the proof
-- complete. If this is undesirable bahavior, use cutOnSolvedSingleThreadDFS.
--
-- FIXME: Note that this function may use a lot of space, as it holds onto the
-- whole proof tree.
cutOnSolvedDFS :: Proof (Maybe a) -> Proof (Maybe a)
cutOnSolvedDFS prf0 =
    go (4 :: Integer) $ insertPaths prf0
  where
    go dMax prf = case findSolved 0 prf of
        NoSolution      -> prf0
        MaybeNoSolution -> go (2 * dMax) prf
        Solution path   -> extractSolved path prf0
      where
        findSolved d node
          | d >= dMax = MaybeNoSolution
          | otherwise = case node of
              -- do not search in nodes that are not annotated
              LNode (ProofStep _ _     (Nothing, _   )) _  -> NoSolution
              LNode (ProofStep (Finished Solved) _ (Just _ , path)) _  -> Solution path
              LNode (ProofStep _ _     (Just _ , _   )) cs ->
                  foldMap (findSolved (succ d))
                      (cs `using` parTraversable nfProofMethod)

        nfProofMethod node = do
            void $ rseq (psMethod $ root node)
            void $ rseq (psInfo   $ root node)
            void $ rseq (children node)
            return node

    extractSolved []         p               = p
    extractSolved (label:ps) (LNode pstep m) = case M.lookup label m of
        Just subprf ->
          LNode pstep (M.fromList [(label, extractSolved ps subprf)])
        Nothing     ->
          error "Theory.Constraint.cutOnSolvedDFS: impossible, extractSolved failed, invalid path"

-- | @cutOnSolvedDFSDiff prf@ removes all other cases if an attack is found. The
-- attack search is performed using a parallel DFS traversal with iterative
-- deepening.
-- Note that when an attack is found, other, already started threads will not be
-- stopped. They will first run to completion, and only afterwards will the proof
-- complete. If this is undesirable bahavior, use cutOnSolvedSingleThreadDFSDiff.
--
-- FIXME: Note that this function may use a lot of space, as it holds onto the
-- whole proof tree.
cutOnSolvedDFSDiff :: DiffProof (Maybe a) -> DiffProof (Maybe a)
cutOnSolvedDFSDiff prf0 =
    go (4 :: Integer) $ insertPathsDiff prf0
  where
    go dMax prf = case findSolved 0 prf of
        NoSolution      -> prf0
        MaybeNoSolution -> go (2 * dMax) prf
        Solution path   -> extractSolved path prf0
      where
        findSolved d node
          | d >= dMax = MaybeNoSolution
          | otherwise = case node of
              -- do not search in nodes that are not annotated
              LNode (DiffProofStep _          (Nothing, _   )) _  -> NoSolution
              LNode (DiffProofStep DiffAttack (Just _ , path)) _  -> Solution path
              LNode (DiffProofStep _          (Just _ , _   )) cs ->
                  foldMap (findSolved (succ d))
                      (cs `using` parTraversable nfProofMethod)

        nfProofMethod node = do
            void $ rseq (dpsMethod $ root node)
            void $ rseq (dpsInfo   $ root node)
            void $ rseq (children node)
            return node

    extractSolved []         p               = p
    extractSolved (label:ps) (LNode pstep m) = case M.lookup label m of
        Just subprf ->
          LNode pstep (M.fromList [(label, extractSolved ps subprf)])
        Nothing     ->
          error "Theory.Constraint.cutOnSolvedDFSDiff: impossible, extractSolved failed, invalid path"

-- | Search for attacks in a BFS manner.
cutOnSolvedBFS :: Proof (Maybe a) -> Proof (Maybe a)
cutOnSolvedBFS =
    go (1::Int)
  where
    go l prf =
      -- FIXME: See if that poor man's logging could be done better.
      trace ("searching for attacks at depth: " ++ show l) $
        case S.runState (checkLevel l prf) CompleteProof of
          (_, UndeterminedProof) -> error "cutOnSolvedBFS: impossible"
          (_, CompleteProof)     -> prf
          (_, UnfinishableProof) -> prf
          (_, IncompleteProof)   -> go (l+1) prf
          (prf', TraceFound)     ->
              trace ("attack found at depth: " ++ show l) prf'

    checkLevel 0 (LNode  step@(ProofStep (Finished Solved) _ (Just _)) _) =
        S.put TraceFound >> return (LNode step M.empty)
    checkLevel 0 prf@(LNode (ProofStep _ blacklist x) cs)
      | M.null cs = return prf
      | otherwise = do
          st <- S.get
          msg <- case st of
              TraceFound -> return $ "ignored (attack exists)"
              _           -> S.put IncompleteProof >> return "bound reached"
          return $ LNode (ProofStep (Sorry (Just msg)) blacklist x) M.empty
    checkLevel l prf@(LNode step cs)
      | isNothing (psInfo step) = return prf
      | otherwise               = LNode step <$> traverse (checkLevel (l-1)) cs

-- | Search for attacks in a BFS manner.
cutOnSolvedBFSDiff :: DiffProof (Maybe a) -> DiffProof (Maybe a)
cutOnSolvedBFSDiff =
    go (1::Int)
  where
    go l prf =
      -- FIXME: See if that poor man's logging could be done better.
      trace ("searching for attacks at depth: " ++ show l) $
        case S.runState (checkLevel l prf) CompleteProof of
          (_, UndeterminedProof) -> error "cutOnSolvedBFS: impossible"
          (_, CompleteProof)     -> prf
          (_, UnfinishableProof) -> prf
          (_, IncompleteProof)   -> go (l+1) prf
          (prf', TraceFound)     ->
              trace ("attack found at depth: " ++ show l) prf'

    checkLevel 0 (LNode  step@(DiffProofStep DiffAttack (Just _)) _) =
        S.put TraceFound >> return (LNode step M.empty)
    checkLevel 0 prf@(LNode (DiffProofStep _ x) cs)
      | M.null cs = return prf
      | otherwise = do
          st <- S.get
          msg <- case st of
              TraceFound -> return $ "ignored (attack exists)"
              _           -> S.put IncompleteProof >> return "bound reached"
          return $ LNode (DiffProofStep (DiffSorry (Just msg)) x) M.empty
    checkLevel l prf@(LNode step cs)
      | isNothing (dpsInfo step) = return prf
      | otherwise                = LNode step <$> traverse (checkLevel (l-1)) cs

cutAfterFirstSorry :: Proof (Maybe a) -> Proof (Maybe a)
cutAfterFirstSorry = snd . go False
  where
    go :: Bool -> Proof (Maybe a) -> (Bool, Proof (Maybe a))
    go _      n@(LNode (ProofStep (Sorry _) _ _) _)     = (True, n)
    go abort  n@(LNode (ProofStep (Finished _) _ _) _)  = (abort, n)
    go True     (LNode (ProofStep _ _ ann) _)           = (True, LNode (ProofStep (Sorry Nothing) [] ann) M.empty)
    go False    (LNode r cs) =
      let (abort, cs') = M.mapAccum go False cs
      in (abort, LNode r cs')


cutAfterFirstSorryDiff :: DiffProof (Maybe a) -> DiffProof (Maybe a)
cutAfterFirstSorryDiff = snd . go False
  where
    go :: Bool -> DiffProof (Maybe a) -> (Bool, DiffProof (Maybe a))
    go _      n@(LNode (DiffProofStep (DiffSorry _) _) _)     = (True, n)
    go abort  n@(LNode (DiffProofStep DiffMirrored _) _)      = (abort, n)
    go abort  n@(LNode (DiffProofStep DiffUnfinishable _) _)  = (abort, n)
    go abort  n@(LNode (DiffProofStep DiffAttack _) _)        = (abort, n)
    go True     (LNode (DiffProofStep _ ann) _)               = (True, LNode (DiffProofStep (DiffSorry Nothing) ann) M.empty)
    go False    (LNode r cs) =
      let (abort, cs') = M.mapAccum go False cs
      in (abort, LNode r cs')

proveSystemDFS :: Bool -> AutomatedProofStrategy -> Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> [Maybe Goal] -> Proof (Maybe System)
proveSystemDFS exportGoals proofStrategy heuristic tactics ctxt d sys skipList = proveSystemDFS' heuristic tactics ctxt d sys'
  where
    sys' = L.set sProofStrategy proofStrategy sys
    proveSystemDFS' = case proofStrategy of
      Original    -> proveSystemDFSOg
      Escape _    -> escapeProveSystemDFS exportGoals
      Proba _     -> probabilisticProveSystemDFS exportGoals
      Backtrack _ -> backtrackProveSystemDFS exportGoals
      BackAndAvoid _ -> backAndAvoidProveSystemDFS exportGoals
      CollectAndRestart _ -> collectAndRestartProveSystemDFS exportGoals skipList


exportGoalsForTactic :: Bool -> Int -> Maybe Goal -> Proof (Maybe System) -> Proof (Maybe System)-- -> ([(ProofMethod, (M.Map CaseName System, String))] -> (ProofMethod, (M.Map CaseName System, String)) -> Proof (Maybe System)) -> ([(ProofMethod, (M.Map CaseName System, String))] -> (ProofMethod, (M.Map CaseName System, String)) -> Proof (Maybe System))
exportGoalsForTactic exportGoals depth g proof = case g of
    Nothing -> proof -- checkForLoop
    Just goal -> if exportGoals
      then trace ("---"++show depth++"---"++show (cleanGoal goal)) proof
      else proof

-- | @proveSystemDFS rules se@ explores all solutions of the initial
-- constraint system using a depth-first-search strategy to resolve the
-- non-determinism wrt. what goal to solve next.  This proof can be of
-- infinite depth, if the proof strategy loops.
proveSystemDFSOg :: Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> Proof (Maybe System)
proveSystemDFSOg heuristic tactics ctxt = prove
  where
    prove !depth sys = case rankProofMethods (useHeuristic heuristic depth) tactics ctxt sys of
          [] | finishedSubterms ctxt sys  -> node (Finished Solved) M.empty
          []                              -> node (Finished $ Unfinishable []) M.empty
          (method, (cases, _expl)):_      -> node method cases
      where
        node method cases =
          LNode (ProofStep method [] (Just sys)) (M.map (prove (succ depth)) cases)

escapeProveSystemDFS :: Bool -> Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> Proof (Maybe System)
escapeProveSystemDFS exportGoals heuristic tactics ctxt = --error "escapeProveSystemDFS: not implemented yet"
    prove
  where
    prove !depth sys = case rankProofMethods (useHeuristic heuristic depth) tactics ctxt sys of
          [] | finishedSubterms ctxt sys  -> node (Finished Solved) M.empty
          []                              -> node (Finished $ Unfinishable []) M.empty
          ((method, (cases, _expl)):suite) -> checkForLoop ((method, (cases, _expl)):suite) (method, (cases, _expl))
      where
        checkForLoop :: [(ProofMethod, (M.Map CaseName System, String))] -> (ProofMethod, (M.Map CaseName System, String)) -> Proof (Maybe System)
        checkForLoop [] (method0, (cases0, _expl0)) = node method0 cases0 --exportGoals generatedTactic method0 cases0
        checkForLoop ((method, (cases, _expl)):suite) (method0, (cases0, _expl0)) = case method of
            InLoop (_,_,g) -> exportGoalsForTactic exportGoals depth g $ checkForLoop suite (method0, (cases0, _expl0))
            _ -> node method cases

        node method cases = LNode (ProofStep method [](Just sys)) (M.map (prove (succ depth)) cases)

probabilisticProveSystemDFS :: Bool -> Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> Proof (Maybe System)
probabilisticProveSystemDFS exportGoals heuristic tactics ctxt d0 sys0 =
  prove d0 sys0
  where

    -- probabilistic
    -- Randomly choosing whether to go in a loop or not, 
    -- loops are not deprioritized

    prove !depth sys =
      case rankProofMethods (useHeuristic heuristic depth) tactics ctxt sys of
          [] | finishedSubterms ctxt sys  -> node (Finished Solved) M.empty sys
          []                              -> node (Finished $ Unfinishable []) M.empty sys
          ((method, (cases, _expl)):suite) -> checkForLoop (sSeed sys) ((method, (cases, _expl)):suite) (method, cases)
      where
        checkForLoop :: StdGen ->[(ProofMethod, (M.Map CaseName System,String))] -> (ProofMethod, M.Map CaseName System) -> Proof (Maybe System)
        --Change in the case no more option, instead of leaving, pushing through the last option: needs to be tested independently
        checkForLoop seed [] (method0, cases0) = node method0 (M.map (changeSeed seed) cases0) sys
        checkForLoop seed ((method, (cases, _expl)):suite) (method0, cases0) = 
            case method of
            InLoop (d,iteration,goal) -> 
              let (chosenLoop,newSeed) = chooseLoop seed d iteration (length $ sPathGoals sys) in
                if chosenLoop
                  then exportGoalsForTactic exportGoals depth goal $ node (InLoop (d,iteration,goal)) (M.map (applyIteration d newSeed) cases) sys
                  else exportGoalsForTactic exportGoals depth goal (checkForLoop newSeed suite (method0, cases0))
            _ -> node method (snd $ M.mapAccum (\g sys -> let (g1,g2) = split g in  (g1, changeSeed g2 sys)) seed cases) sys

        chooseLoop :: StdGen -> Int -> Int -> Int -> (Bool,StdGen)
        chooseLoop seed _depth iteration maxd = (rand <= threshold, newSeed)
            where
                it = int2Double iteration
                d = int2Double _depth
                md = int2Double maxd
                (pickedRand,newSeed) = randomR (0, _depth) seed
                rand = int2Double pickedRand / d
                threshold = 1.0/(2**(it+(md - d)))

        incrementIteration :: Int -> [(Int,Int,[Goal])] -> Int -> [(Int,Int,[Goal])] -> [(Int,Int,[Goal])]
        incrementIteration 0 ((d,it,g):t) _ _ = (d,it+1,g):t
        incrementIteration _ [] removeint removelist = error (show removeint++" "++show (length removelist)++"\n"++show removelist)
        incrementIteration _depth (h:t) removeint removelist = h:incrementIteration (_depth-1) t removeint removelist

        applyIteration :: Int -> StdGen -> System -> System
        applyIteration idx seed _sys = L.set sProofStrategy strat _sys
          where
            strat = Proba (ProbaStrat (incrementIteration idx (sPathGoals _sys) idx (sPathGoals _sys)) (sNbLoop _sys) (sLoopFound _sys) seed)

        changeSeed :: StdGen -> System -> System
        changeSeed seed _sys = L.set sProofStrategy strat _sys
          where
            strat = Proba (ProbaStrat (sPathGoals _sys) (sNbLoop _sys) (sLoopFound _sys) seed)

        node method cases _sys = LNode (ProofStep method [] (Just _sys)) (M.map (prove (succ depth)) cases)

backtrackProveSystemDFS :: Bool -> Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> Proof (Maybe System)
backtrackProveSystemDFS exportGoals heuristic tactics ctxt d0 sys0 =
      prove d0 [] sys0 
  where
      prove !depth ignoreGoals sys = case rankProofMethods (useHeuristic heuristic depth) tactics ctxt sys of
        [] | finishedSubterms ctxt sys  -> node (Finished Solved) M.empty ignoreGoals
        []                              -> node (Finished $ Unfinishable []) M.empty ignoreGoals
        ((method, (cases, _expl)):suite) -> explore ((method, (cases, _expl)):suite) (method,cases) ignoreGoals

        where
          explore :: [(ProofMethod, (M.Map CaseName System,String))] -> (ProofMethod, M.Map CaseName System) -> [Int] -> Proof (Maybe System)
          explore [] (method0, cases0) igG = node method0 cases0 (depth:igG) 
          explore ((InLoop (n,i,g), (cases, _expl)):_) _ igG = exportGoalsForTactic exportGoals depth g $
              if (depth-n) `elem` igG
                then node (InLoop (n,i,g)) cases igG 
                else node (InLoop (n,i,g)) M.empty igG --else 
          explore ((method, (cases, _expl)):suite) (method0, cases0) igG = case propagatedMethod of --
              InLoop (0,_,_) -> explore suite (method0,cases0) igG --
              InLoop (n,i,g) ->
                  if (depth-n) `elem` igG
                    then node (InLoop (n,i,g)) cases igG 
                    else node (InLoop (n,i,g)) M.empty igG   --
              _            -> node method cases igG
            where
                propagatedMethod = propagateMethod cases method igG


          propagateMethod cases methodOrigin ignore = case propagatingMethod (Sorry Nothing) (M.toList cases) of
              InLoop (0,_,_) -> if not (null ignore)
                                then propagateMethod cases methodOrigin []
                                else methodOrigin                          --  
              InLoop (s,i,_) -> InLoop (s-1,i,extractGoal methodOrigin) --
              _            -> methodOrigin                          --
            where
              propagatingMethod :: ProofMethod -> [(CaseName,System)] -> ProofMethod
              propagatingMethod method [] = method
              propagatingMethod method ((_,_sys):t) = case prove (succ depth) ignoreGoals _sys  of
                  (LNode (ProofStep (InLoop (s,i,g)) _ _ ) _) -> InLoop (s,i,g)
                  (LNode _ _)                           -> propagatingMethod method t

          extractGoal method = case method of
            InLoop (_,_, goal) -> goal
            SolveGoal goal     -> Just goal
            _ -> Nothing

          node :: ProofMethod -> M.Map CaseName System -> [Int] -> Proof(Maybe System)
          node methodOrigin casesOrigin igG = nodule
                  where
                    successors = M.map (prove (succ depth) igG) casesOrigin
                    nodule = LNode (ProofStep methodOrigin [](Just sys)) successors

backAndAvoidProveSystemDFS :: Bool -> Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> Proof (Maybe System)
backAndAvoidProveSystemDFS exportGoals heuristic tactics ctxt d0 sys0 =
      prove d0 [] [] sys0
  where
      prove !depth ignoreGoals blacklist sys = case rankProofMethods (useHeuristic heuristic depth) tactics ctxt sys of
        [] | finishedSubterms ctxt sys  -> node (Finished Solved) M.empty ignoreGoals blacklist
        []                              -> node (Finished $ Unfinishable []) M.empty ignoreGoals blacklist
        ((method, (cases, _expl)):suite) -> explore ((method, (cases, _expl)):suite) (method,cases) ignoreGoals blacklist

        where
          explore :: [(ProofMethod, (M.Map CaseName System,String))] -> (ProofMethod, M.Map CaseName System) -> [Int] -> [Maybe Goal] -> Proof (Maybe System)
          explore [] (method0, cases0) igG _blacklist = node method0 cases0 (depth:igG) _blacklist
          explore ((InLoop (n,it,g), (cases, _expl)):_) _ igG _blacklist = exportGoalsForTactic exportGoals depth g $
              if (depth-n) `elem` igG 
                then node (InLoop (n,it,g)) cases igG _blacklist
                else node (InLoop (n,it,g)) M.empty igG (fmap cleanGoal g:_blacklist)
          explore ((method, (cases, _expl)):suite) (method0, cases0) igG _blacklist = 
            if fmap cleanGoal (extractGoal method) `elem` _blacklist
              then 
                explore suite (method0,cases0) igG _blacklist
              else 
                case propagatedMethod of --
                  InLoop (0,_,_) -> explore suite (method0,cases0) igG newbl
                  InLoop (n,it,g) -> if (depth-n) `elem` igG 
                                    then node (InLoop (n,it,g)) cases igG newbl
                                    else node (InLoop (n,it,g)) M.empty igG newbl --
                  _            -> node method cases igG newbl
                where
                    (propagatedMethod, newbl) = propagateMethod cases method igG _blacklist


          propagateMethod cases methodOrigin ignore _blacklist = case propagatingMethod (Sorry Nothing) (M.toList cases) _blacklist of
              (InLoop (0,_,_),nbl) -> if not (null ignore)
                                then propagateMethod cases methodOrigin [] nbl
                                else (methodOrigin,nbl)                          --  
              (InLoop (s,it,_),nbl) -> (InLoop (s-1,it,extractGoal methodOrigin),nbl) --
              (_, nbl)           -> (methodOrigin,nbl)                          --
            where
              propagatingMethod :: ProofMethod -> [(CaseName,System)] -> [Maybe Goal] -> (ProofMethod,[Maybe Goal])
              propagatingMethod method [] _blacklist = (method,_blacklist)
              propagatingMethod method ((_,_sys):t) _blacklist = case prove (succ depth) ignoreGoals _blacklist _sys  of
                  (LNode (ProofStep (InLoop (s,it,g)) newbl _ ) _) -> (InLoop (s,it,g),newbl)
                  (LNode _ _)                           -> propagatingMethod method t _blacklist

          extractGoal method = case method of
            InLoop (_, _, goal) -> goal
            SolveGoal goal     -> Just goal
            _ -> Nothing

          node :: ProofMethod -> M.Map CaseName System -> [Int] -> [Maybe Goal] -> Proof(Maybe System)
          node methodOrigin casesOrigin igG _blacklist =  trace (show nodule) nodule
            where
                successors = M.map (prove (succ depth) igG _blacklist) casesOrigin
                nodule = LNode (ProofStep methodOrigin _blacklist (Just sys)) successors

collectAndRestartProveSystemDFS :: Bool -> [Maybe Goal] -> Heuristic ProofContext -> [Tactic ProofContext] -> ProofContext -> Int -> System -> Proof (Maybe System)
collectAndRestartProveSystemDFS exportGoals skipList0 heuristic tactics ctxt d0 sys0  = prove d0 skipList0 sys0
  where
    
    prove !depth skip sys = case ranked of 
          [] | finishedSubterms ctxt sys  -> node skip (Finished Solved) M.empty
          []                              -> node [] (Finished $ Unfinishable []) M.empty
          ((method, (cases, _expl)):suite) -> if not (checkBacktracking depth sys) || isNothing (extractGoal method)
                                                then 
                                                      checkForLoop skip ((method, (cases, _expl)):suite) (method, (cases, _expl))
                                                else
                                                      node skip (Incorrect (incorrectnessScore method+1,depth, extractGoal method,skip)) M.empty --we are going to backtrack so this node will disappear
      where
        ranked = rankProofMethods (useHeuristic heuristic depth) tactics ctxt sys 

        checkBacktracking :: Int -> System -> Bool
        -- alpha = 20 and delta = 3 lifted from SmartVerif paper
        checkBacktracking _depth _system = _depth > 10 && countLoop (sPathGoals sys) > 1

        checkForLoop :: [Maybe Goal] ->  [(ProofMethod, (M.Map CaseName System, String))] -> (ProofMethod, (M.Map CaseName System, String)) -> Proof (Maybe System)
        --Change in the case no more option, instead of leaving, pushing through the last option: needs to be tested independently
        checkForLoop s [] (method0, (cases0, _expl0)) = node skipL propagMethod cs 
          where
              (propagMethod, cs, skipL) = propagatedMethod cases0 method0 
        checkForLoop s ((method, (cases, _expl)):suite) (method0, (cases0, _expl0)) =
            if goal `elem` s
              then case method of
                InLoop _ -> exportGoalsForTactic exportGoals depth goal $ checkForLoop s suite (method0, (cases0, _expl0))
                _              ->  checkForLoop s suite (method0, (cases0, _expl0))
              else node skipL propagMethod cs 
            where
              goal = cleanGoal <$> extractGoal method
              (propagMethod, cs, skipL) = propagatedMethod cases method 

        node skipList methodOrigin cases = if cases == M.empty  
          then LNode (ProofStep methodOrigin [] (Just sys)) M.empty 
          else LNode (ProofStep  methodOrigin [] (Just sys)) (M.map (prove (succ depth) skipList) cases)

        propagatedMethod cases methodOrigin = case propagatingMethod skip (Sorry Nothing,"",M.empty) (M.toList cases) of
                (Incorrect (_,1, g, skl),_,_)  -> (Finished $ Unfinishable skl, M.empty,skl++[cleanGoal <$> g])
                (Incorrect (scr, d, g, skl),_,pf) ->
                      (Incorrect (scr, d-1, extractGoal methodOrigin,skl++[cleanGoal<$> g]),
                      M.empty,skl++[cleanGoal <$> g])
                (_,_,pf)                  -> (methodOrigin, cases, skip)
           where
                propagatingMethod :: [Maybe Goal] -> (ProofMethod,CaseName,M.Map CaseName (LTree CaseName (ProofStep (Maybe System)))) -> [(CaseName,System)]
                                    -> (ProofMethod,CaseName,M.Map CaseName (LTree CaseName (ProofStep (Maybe System))))
                propagatingMethod _ (m,cn,proof) [] = (m,cn,proof) 
                propagatingMethod updateSkipList (m0,cn0,proof) ((cn,_sys):t) = case prove (succ depth) updateSkipList _sys of
                  (LNode (ProofStep (Incorrect (_s,d,g,skl)) _ _ ) _) -> if extractBadDepth m0 > d then error "Inconsistent depth" else (Incorrect (_s,d,g,skl),cn,proof) --(m0,cn0,proof)
                  (LNode ps cs) -> propagatingMethod updateSkipList (m0,cn0,M.insert cn (LNode ps cs) proof) t 

        extractGoal :: ProofMethod -> Maybe Goal
        extractGoal method = case method of
            InLoop (_, _, goal)    -> goal
            Incorrect (_,_,goal,_) -> goal
            SolveGoal goal         -> Just goal
            _ -> Nothing
        
        extractBadDepth :: ProofMethod -> Int
        extractBadDepth method = case method of
            Incorrect (_,d,_,_)  -> d
            _ -> 0

        incorrectnessScore :: ProofMethod -> Int
        incorrectnessScore (Incorrect (s,_,_,_)) = s
        incorrectnessScore _ = 0

        countLoop :: [(Int,Int,[Goal])] -> Int
        countLoop []          = 0
        countLoop ((_,0,_):t) = countLoop t
        countLoop ((_,_,_):t) = 1 + countLoop t
        
        isIncorrect :: ProofMethod -> Bool
        isIncorrect method = case method of
            Incorrect _ -> True
            _ -> False

-- | @proveSystemDFS rules se@ explores all solutions of the initial
-- constraint system using a depth-first-search strategy to resolve the
-- non-determinism wrt. what goal to solve next.  This proof can be of
-- infinite depth, if the proof strategy loops.
proveDiffSystemDFS :: Heuristic ProofContext -> [Tactic ProofContext] -> DiffProofContext -> Int -> DiffSystem -> DiffProof (Maybe DiffSystem)
proveDiffSystemDFS heuristic tactics ctxt =
    prove
  where
    prove !depth sys =
        case rankDiffProofMethods (useHeuristic heuristic depth) tactics ctxt sys of
          []                         -> node (DiffSorry (Just "Cannot prove")) M.empty
          (method, (cases, _expl)):_ -> node method cases
      where
        node method cases =
          LNode (DiffProofStep method (Just sys)) (M.map (prove (succ depth)) cases)

------------------------------------------------------------------------------
-- Pretty printing
------------------------------------------------------------------------------


prettyProof :: HighlightDocument d => Proof a -> d
prettyProof = prettyProofWith (prettyProofMethod . psMethod) (const id)

prettyProofWith :: HighlightDocument d
                => (ProofStep a -> d)      -- ^ Make proof step pretty
                -> (ProofStep a -> d -> d) -- ^ Make whole case pretty
                -> Proof a                 -- ^ The proof to prettify
                -> d
prettyProofWith prettyStep prettyCase =
    ppPrf
  where
    ppPrf (LNode ps cs) = ppCases ps (M.toList cs)

    ppCases ps@(ProofStep (Finished Solved) _ _) [] = prettyStep ps
    ppCases ps []                      = prettyCase ps (kwBy <> text " ")
                                           <> prettyStep ps
    ppCases ps [("", prf)]             = prettyStep ps $-$ ppPrf prf
    ppCases ps cases                   =
        prettyStep ps $-$
        (vcat $ intersperse (prettyCase ps kwNext) $ map ppCase cases) $-$
        prettyCase ps kwQED

    ppCase (name, prf) = nest 2 $
      (prettyCase (root prf) $ kwCase <-> text name) $-$
      ppPrf prf

prettyDiffProof :: HighlightDocument d => DiffProof a -> d
prettyDiffProof = prettyDiffProofWith (prettyDiffProofMethod . dpsMethod) (const id)

prettyDiffProofWith :: HighlightDocument d
                => (DiffProofStep a -> d)      -- ^ Make proof step pretty
                -> (DiffProofStep a -> d -> d) -- ^ Make whole case pretty
                -> DiffProof a                 -- ^ The proof to prettify
                -> d
prettyDiffProofWith prettyStep prettyCase =
    ppPrf
  where
    ppPrf (LNode ps cs) = ppCases ps (M.toList cs)

    ppCases ps@(DiffProofStep DiffMirrored _) [] = prettyStep ps
    ppCases ps []                              = prettyCase ps (kwBy <> text " ")
                                                  <> prettyStep ps
    ppCases ps [("", prf)]                     = prettyStep ps $-$ ppPrf prf
    ppCases ps cases                           =
        prettyStep ps $-$
        (vcat $ intersperse (prettyCase ps kwNext) $ map ppCase cases) $-$
        prettyCase ps kwQED

    ppCase (name, prf) = nest 2 $
      (prettyCase (root prf) $ kwCase <-> text name) $-$
      ppPrf prf

-- | Convert a proof status to a readable string.
showProofStatus :: SystemTraceQuantifier -> ProofStatus -> String
showProofStatus ExistsNoTrace   TraceFound        = "falsified - found trace"
showProofStatus ExistsNoTrace   CompleteProof     = "verified"
showProofStatus ExistsSomeTrace CompleteProof     = "falsified - no trace found"
showProofStatus ExistsSomeTrace TraceFound        = "verified"
showProofStatus _               UnfinishableProof = "analysis cannot be finished (reducible operators in subterms)"
showProofStatus _               IncompleteProof   = "analysis incomplete"
showProofStatus _               UndeterminedProof = "analysis undetermined"
showProofStatus _               InvalidatedProof  = "proof has been invalidated"

-- | Convert a proof status to a readable string.
showDiffProofStatus :: ProofStatus -> String
showDiffProofStatus TraceFound        = "falsified - found trace"
showDiffProofStatus CompleteProof     = "verified"
showDiffProofStatus UnfinishableProof = "analysis cannot be finished (reducible operators in subterms)"
showDiffProofStatus IncompleteProof   = "analysis incomplete"
showDiffProofStatus UndeterminedProof = "analysis undetermined"
showDiffProofStatus InvalidatedProof  = "proof has been invalidated"

-- Instances
--------------------
instance (Ord l, NFData l, NFData a) => NFData (LTree l a) where
  rnf (LNode r m) = rnf r `seq` rnf  m

instance (Ord l, Binary l, Binary a) => Binary (LTree l a) where
  put (LNode r m) = put r >> put m
  get = LNode <$> get <*> get
