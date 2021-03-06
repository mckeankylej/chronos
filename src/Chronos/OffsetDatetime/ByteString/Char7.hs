{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}

-- | The naming conventions for offsets that are used in
--   function names are as follows:
--
--   * @%z@ - @z@ +hhmm numeric time zone (e.g., -0400)
--   * @%:z@ - @z1@ +hh:mm numeric time zone (e.g., -04:00)
--   * @%::z@ - @z2@ +hh:mm:ss numeric time zone (e.g., -04:00:00)
--   * @%:::z@ - @z3@ numeric time zone with : to necessary precision (e.g., -04, +05:30)

module Chronos.OffsetDatetime.ByteString.Char7 where

import Chronos.Types
import Data.ByteString (ByteString)
import Data.ByteString.Builder (Builder)
import Data.Vector (Vector)
import Data.Monoid
import Data.Attoparsec.ByteString (Parser)
import Control.Monad
import Data.Foldable
import Data.Int
import qualified Chronos.Internal as I
import qualified Chronos.Datetime.ByteString.Char7 as Datetime
import qualified Chronos.TimeOfDay.ByteString.Char7 as TimeOfDay
import qualified Data.ByteString.Char8 as ByteString
import qualified Data.Attoparsec.ByteString.Char8 as Atto
import qualified Data.Vector as Vector
import qualified Data.ByteString.Builder as Builder

builder_YmdHMSz :: OffsetFormat -> SubsecondPrecision -> DatetimeFormat -> OffsetDatetime -> Builder
builder_YmdHMSz offsetFormat sp datetimeFormat (OffsetDatetime datetime offset) =
     Datetime.builder_YmdHMS sp datetimeFormat datetime
  <> offsetBuilder offsetFormat offset

parser_YmdHMSz :: OffsetFormat -> DatetimeFormat -> Parser OffsetDatetime
parser_YmdHMSz offsetFormat datetimeFormat = OffsetDatetime
  <$> Datetime.parser_YmdHMS datetimeFormat
  <*> offsetParser offsetFormat

builder_YmdIMS_p_z :: OffsetFormat -> MeridiemLocale ByteString -> SubsecondPrecision -> DatetimeFormat -> OffsetDatetime -> Builder
builder_YmdIMS_p_z offsetFormat meridiemLocale sp datetimeFormat (OffsetDatetime datetime offset) =
     Datetime.builder_YmdIMS_p meridiemLocale sp datetimeFormat datetime
  <> " "
  <> offsetBuilder offsetFormat offset

builderW3 :: OffsetDatetime -> Builder
builderW3 = builder_YmdHMSz
  OffsetFormatColonOn
  SubsecondPrecisionAuto
  (DatetimeFormat (Just '-') (Just 'T') (Just ':'))

offsetBuilder :: OffsetFormat -> Offset -> Builder
offsetBuilder x = case x of
  OffsetFormatColonOff -> buildOffset_z
  OffsetFormatColonOn -> buildOffset_z1
  OffsetFormatSecondsPrecision -> buildOffset_z2
  OffsetFormatColonAuto -> buildOffset_z3

offsetParser :: OffsetFormat -> Parser Offset
offsetParser x = case x of
  OffsetFormatColonOff -> parseOffset_z
  OffsetFormatColonOn -> parseOffset_z1
  OffsetFormatSecondsPrecision -> parseOffset_z2
  OffsetFormatColonAuto -> parseOffset_z3

-- | True means positive, false means negative
parseSignedness :: Parser Bool
parseSignedness = do
  c <- Atto.anyChar
  if c == '-'
    then return False
    else if c == '+'
      then return True
      else fail "while parsing offset, expected [+] or [-]"
{-# INLINE parseSignedness #-}

parseOffset_z :: Parser Offset
parseOffset_z = do
  pos <- parseSignedness
  h <- I.parseFixedDigitsIntBS 2
  m <- I.parseFixedDigitsIntBS 2
  let !res = h * 60 + m
  return . Offset $ if pos
    then res
    else negate res

parseOffset_z1 :: Parser Offset
parseOffset_z1 = do
  pos <- parseSignedness
  h <- I.parseFixedDigitsIntBS 2
  _ <- Atto.char ':'
  m <- I.parseFixedDigitsIntBS 2
  let !res = h * 60 + m
  return . Offset $ if pos
    then res
    else negate res

parseOffset_z2 :: Parser Offset
parseOffset_z2 = do
  pos <- parseSignedness
  h <- I.parseFixedDigitsIntBS 2
  _ <- Atto.char ':'
  m <- I.parseFixedDigitsIntBS 2
  _ <- Atto.string ":00"
  let !res = h * 60 + m
  return . Offset $ if pos
    then res
    else negate res

-- | This is generous in what it accepts. If you give
--   something like +04:00 as the offset, it will be
--   allowed, even though it could be shorter.
parseOffset_z3 :: Parser Offset
parseOffset_z3 = do
  pos <- parseSignedness
  h <- I.parseFixedDigitsIntBS 2
  mc <- Atto.peekChar
  case mc of
    Just ':' -> do
      _ <- Atto.anyChar -- should be a colon
      m <- I.parseFixedDigitsIntBS 2
      let !res = h * 60 + m
      return . Offset $ if pos
        then res
        else negate res
    _ -> return . Offset $ if pos
      then h * 60
      else h * (-60)

buildOffset_z :: Offset -> Builder
buildOffset_z (Offset i) =
  let (!a,!b) = divMod (abs i) 60
      !prefix = if signum i == (-1) then "-" else "+"
   in prefix
      <> I.indexTwoDigitByteStringBuilder a
      <> I.indexTwoDigitByteStringBuilder b

buildOffset_z1 :: Offset -> Builder
buildOffset_z1 (Offset i) =
  let (!a,!b) = divMod (abs i) 60
      !prefix = if signum i == (-1) then "-" else "+"
   in prefix
      <> I.indexTwoDigitByteStringBuilder a
      <> ":"
      <> I.indexTwoDigitByteStringBuilder b

buildOffset_z2 :: Offset -> Builder
buildOffset_z2 (Offset i) =
  let (!a,!b) = divMod (abs i) 60
      !prefix = if signum i == (-1) then "-" else "+"
   in prefix
      <> I.indexTwoDigitByteStringBuilder a
      <> ":"
      <> I.indexTwoDigitByteStringBuilder b
      <> ":00"

buildOffset_z3 :: Offset -> Builder
buildOffset_z3 (Offset i) =
  let (!a,!b) = divMod (abs i) 60
      !prefix = if signum i == (-1) then "-" else "+"
   in if b == 0
        then prefix
          <> I.indexTwoDigitByteStringBuilder a
        else prefix
          <> I.indexTwoDigitByteStringBuilder a
          <> ":"
          <> I.indexTwoDigitByteStringBuilder b

