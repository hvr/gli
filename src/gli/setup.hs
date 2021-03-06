{-# LANGUAGE OverloadedStrings #-}

module Gli.Setup where

import qualified Data.Attoparsec.Text as P
import qualified Data.Map.Strict      as M
import qualified Data.Text            as T
import           Data.Yaml
import           Gli.Gitlab
import           Gli.Types
import           Network.URI
import           System.Process

setupProject :: String -> IO ()
setupProject file = do
  origin <- readProcess "git"
            ["config", "--get", "remote.origin.url"]
            ""
  case P.parseOnly parseGitUrl (T.pack (origin)) of
    Left  msg    -> print msg
    Right gitUrl -> do
      print gitUrl
      cfg <- decodeFile file :: IO (Maybe GliCfg)
      case cfg of
        Nothing -> putStrLn $ mappend "Unable to parse file " (show file)
        Just b  -> if M.null matchedKeyVal
          then putStrLn $ mappend "Unable to find a relevent key for \
                                  \the domain, please check the config \
                                  \file " (show file)
          else do
          project <- getProject
            (T.strip (T.pack origin)) (head $ M.elems $  matchedKeyVal)
          encodeFile localYmlFile (LocalYmlContent
                                   (MasterFileConfig file matchedKey)
                                    project)
          appendFile gitInfoExcludeFile localYmlFile
          where
            matchedKey = head $ M.keys $ matchedKeyVal
            matchedKeyVal = fetchKeyFromAccount (accounts b) (domain gitUrl)

parseGitUrl :: P.Parser GitUrl
parseGitUrl = do
  _ <- P.string "git@"
  d <- P.takeTill (':' ==)
  _ <- P.char ':'
  r <- P.takeTill ('\n' ==)
  return $ GitUrl d r

fetchKeyFromAccount :: Account -> T.Text -> M.Map T.Text AccountConfig
fetchKeyFromAccount a g =
  M.filter (\v -> g == httpDomainConfig(url v)) (accountMap a)

httpDomainConfig :: String -> T.Text
httpDomainConfig u =
  case parseURI u of
    Nothing -> error "Unable to find remote url"
    Just a  -> case uriAuthority a of
      Nothing -> error "Unable to parse the url"
      Just b  -> T.pack $ uriRegName b

accountMap :: Account -> M.Map T.Text AccountConfig
accountMap (Account acc) = acc
