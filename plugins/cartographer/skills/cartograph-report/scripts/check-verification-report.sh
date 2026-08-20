#!/bin/bash
# Stage-5 verification-report validator — checks a
# .cartographer/verification-report.md against RC-31's record grammar and
# the two gate predicates (RC-32 for Accuracy, core/effectiveness-
# verification.md RC-35 for Effectiveness).
# Contract: RC-36 (invocation, INVALID output grammar, message strings,
# exit codes). Full definitions: core/claim-verification.md.
#
# This script validates format and gate arithmetic. It never judges
# whether a verdict is itself correct — that is the dispatched subagent's
# job (RC-29), not a checker's.
#
# This script is read-only: it never rewrites VERIFICATION_REPORT_FILE and
# writes no file of its own. It never reads the claim ledger — the ledger
# is a working-only artifact (core/claim-model.md) and RC-6's same
# reasoning applies here — so it confirms that `unverified-other=<m>` is a
# non-negative integer and cannot confirm `<m>` against the ledger.
#
# Two pipe-delimited grammars meet here and are not the same grammar: the
# INVALID/SUMMARY lines below are this script's stdout, and the
# RESULT/OVERALL lines are the input file's last three lines (RC-31).
#
# Run: bash check-verification-report.sh <VERIFICATION_REPORT_FILE>

set -u

REPORT_FILE="${1:-}"

if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ] || [ ! -r "$REPORT_FILE" ]; then
  echo "usage: check-verification-report.sh <VERIFICATION_REPORT_FILE>" >&2
  echo "  VERIFICATION_REPORT_FILE must be a readable file" >&2
  exit 2
fi

# ──────────────────────────────────────────────────────────────────────────────
# RC-36 message strings, byte-for-byte. One name per row of the contract's
# table, so a message is never spelled twice in this file.
# ──────────────────────────────────────────────────────────────────────────────

MSG_RECORD_FIELDS='record does not carry exactly five fields'
MSG_SUMMARY_FIELDS='summary line does not carry its stated field count'
MSG_GATE='unknown gate: legal values are accuracy and effectiveness'
MSG_KIND='kind is not legal for this gate'
MSG_VERDICT='verdict is not legal for this gate'
MSG_SUBJECT='claim id does not match ^[A-Za-z0-9._-]+$'
MSG_QUESTION_SUBJECT='question subject is not one of q1 through q5'
MSG_QUESTION_DUPLICATE='question subject appears more than once'
MSG_QUESTION_MISSING='the five question records q1 through q5 are not all present'
MSG_EVIDENCE_SENTINEL='evidence is none on a record that is not an unanswered question'
MSG_EVIDENCE_EMPTY='evidence is empty'
MSG_RESULT_ACCURACY='RESULT accuracy is PASS while a disproved or plausible accuracy record exists'
MSG_RESULT_EFFECTIVENESS='RESULT effectiveness is PASS while an unanswered question record exists'
MSG_ANSWERED_COUNT='RESULT effectiveness answered count does not match the question records'
MSG_DISPATCHED_COUNT='RESULT accuracy dispatched count does not match the accuracy records'
MSG_SPOT_CHECK_COUNT='RESULT accuracy spot-checked numerator does not match the signature and self-citation records'
MSG_OVERALL='OVERALL is PASS while a RESULT line is NEEDS WORK'
MSG_SUMMARY_SHAPE='the three summary lines are not the last three lines of the file, in order'

CLAIM_ID_RE='^[A-Za-z0-9._-]+$'
DISPATCHED_RE='^dispatched=[0-9]+$'
SPOT_CHECKED_RE='^spot-checked=[0-9]+/[0-9]+$'
UNVERIFIED_OTHER_RE='^unverified-other=[0-9]+$'
ANSWERED_RE='^answered=[0-9]+/5$'

INVALID=0

# <LINE> is a 1-based line number in the input file, and 0 for a
# file-level violation (RC-36).
emit() {
  printf 'INVALID|%s|%s\n' "$1" "$2"
  INVALID=$((INVALID + 1))
}

finish() {
  printf 'SUMMARY|invalid=%d\n' "$INVALID"
  if [ "$INVALID" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

# ──────────────────────────────────────────────────────────────────────────────
# READ — blank lines carry no record and are ignored everywhere, including
# in "the last three lines". Reported line numbers are the file's own
# 1-based numbers, blank lines included, so a violation is locatable.
# ──────────────────────────────────────────────────────────────────────────────

LINE_NUMS=()
LINE_TEXTS=()
file_line=0
while IFS= read -r line || [ -n "$line" ]; do
  file_line=$((file_line + 1))
  [ -z "${line//[[:space:]]/}" ] && continue
  LINE_NUMS+=("$file_line")
  LINE_TEXTS+=("$line")
done < "$REPORT_FILE"

TOTAL="${#LINE_TEXTS[@]}"

# ──────────────────────────────────────────────────────────────────────────────
# FILE SHAPE — the three summary lines are the last three lines, in order.
# This violation is terminal: without them the record region has no end, so
# every per-record result below would be an artifact of the miscut rather
# than a finding about a record.
# ──────────────────────────────────────────────────────────────────────────────

if [ "$TOTAL" -lt 3 ]; then
  emit 0 "$MSG_SUMMARY_SHAPE"
  finish
fi

ACC_IDX=$((TOTAL - 3))
EFF_IDX=$((TOTAL - 2))
OVR_IDX=$((TOTAL - 1))

if [[ ${LINE_TEXTS[$ACC_IDX]} != 'RESULT|accuracy|'* ]] \
   || [[ ${LINE_TEXTS[$EFF_IDX]} != 'RESULT|effectiveness|'* ]] \
   || [[ ${LINE_TEXTS[$OVR_IDX]} != 'OVERALL|'* ]]; then
  emit 0 "$MSG_SUMMARY_SHAPE"
  finish
fi

# ──────────────────────────────────────────────────────────────────────────────
# RECORDS — every line before the three summary lines.
# ──────────────────────────────────────────────────────────────────────────────

# Field count without splitting: one more than the number of delimiters.
# `read -a` drops a trailing empty field, which would make a record ending
# in an empty EVIDENCE read as four fields and hide the empty-evidence case
# behind the field-count message.
field_count() {
  local pipes="${1//[^|]/}"
  printf '%d' $(( ${#pipes} + 1 ))
}

ACCURACY_RECORDS=0
ACCURACY_NOT_CONFIRMED=0
SPOT_CHECK_RECORDS=0
QUESTIONS_ANSWERED=0
QUESTIONS_UNANSWERED=0
SEEN_QUESTIONS=" "

idx=0
while [ "$idx" -lt "$ACC_IDX" ]; do
  rec="${LINE_TEXTS[$idx]}"
  ln="${LINE_NUMS[$idx]}"
  idx=$((idx + 1))

  if [ "$(field_count "$rec")" -ne 5 ]; then
    emit "$ln" "$MSG_RECORD_FIELDS"
    continue
  fi

  gate="${rec%%|*}"; rest="${rec#*|}"
  kind="${rest%%|*}"; rest="${rest#*|}"
  subject="${rest%%|*}"; rest="${rest#*|}"
  verdict="${rest%%|*}"; evidence="${rest#*|}"

  gate_known=1
  case "$gate" in
    accuracy)
      ACCURACY_RECORDS=$((ACCURACY_RECORDS + 1))
      case "$kind" in
        behavioral) ;;
        signature|self-citation) SPOT_CHECK_RECORDS=$((SPOT_CHECK_RECORDS + 1)) ;;
        *) emit "$ln" "$MSG_KIND" ;;
      esac
      case "$verdict" in
        confirmed) ;;
        plausible|disproved) ACCURACY_NOT_CONFIRMED=$((ACCURACY_NOT_CONFIRMED + 1)) ;;
        *) emit "$ln" "$MSG_VERDICT" ;;
      esac
      [[ $subject =~ $CLAIM_ID_RE ]] || emit "$ln" "$MSG_SUBJECT"
      ;;
    effectiveness)
      [ "$kind" = "question" ] || emit "$ln" "$MSG_KIND"
      case "$verdict" in
        answered) QUESTIONS_ANSWERED=$((QUESTIONS_ANSWERED + 1)) ;;
        unanswered) QUESTIONS_UNANSWERED=$((QUESTIONS_UNANSWERED + 1)) ;;
        *) emit "$ln" "$MSG_VERDICT" ;;
      esac
      case "$subject" in
        q1|q2|q3|q4|q5)
          if [[ $SEEN_QUESTIONS == *" $subject "* ]]; then
            emit "$ln" "$MSG_QUESTION_DUPLICATE"
          else
            SEEN_QUESTIONS="$SEEN_QUESTIONS$subject "
          fi
          ;;
        *) emit "$ln" "$MSG_QUESTION_SUBJECT" ;;
      esac
      ;;
    *)
      gate_known=0
      emit "$ln" "$MSG_GATE"
      ;;
  esac

  # EVIDENCE is non-empty on every record, and carries the literal `none`
  # if and only if the record is effectiveness|question|<q>|unanswered
  # (RC-31). Both directions are checked; the free prose inside an excerpt
  # is not, because RC-31 states no form for it.
  if [ -z "$evidence" ]; then
    emit "$ln" "$MSG_EVIDENCE_EMPTY"
  elif [ "$evidence" = "none" ]; then
    if [ "$gate_known" -ne 1 ] || [ "$gate" != "effectiveness" ] \
       || [ "$kind" != "question" ] || [ "$verdict" != "unanswered" ]; then
      emit "$ln" "$MSG_EVIDENCE_SENTINEL"
    fi
  fi
done

# Exactly five question records, one per q1 through q5, on every run in
# both modes (core/effectiveness-verification.md RC-35). File-level: no
# single line is the offender when one is absent.
for q in q1 q2 q3 q4 q5; do
  if [[ $SEEN_QUESTIONS != *" $q "* ]]; then
    emit 0 "$MSG_QUESTION_MISSING"
    break
  fi
done

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY LINES — RC-31's six, four, and two bare fields, then each line's
# agreement with the records. A line whose fields are not in RC-31's stated
# form carries the field-count message and is not compared against the
# records: a value that cannot be read cannot be shown to disagree.
# ──────────────────────────────────────────────────────────────────────────────

ACC_LINE="${LINE_TEXTS[$ACC_IDX]}"
ACC_LN="${LINE_NUMS[$ACC_IDX]}"
EFF_LINE="${LINE_TEXTS[$EFF_IDX]}"
EFF_LN="${LINE_NUMS[$EFF_IDX]}"
OVR_LINE="${LINE_TEXTS[$OVR_IDX]}"
OVR_LN="${LINE_NUMS[$OVR_IDX]}"

ACC_RESULT=""
EFF_RESULT=""

# RESULT|accuracy|<PASS or NEEDS WORK>|dispatched=<n>|spot-checked=<n>/<N>|unverified-other=<m>
rest="${ACC_LINE#*|}"; rest="${rest#*|}"
acc_result="${rest%%|*}"; rest="${rest#*|}"
acc_dispatched="${rest%%|*}"; rest="${rest#*|}"
acc_spot="${rest%%|*}"; acc_other="${rest#*|}"

if [ "$(field_count "$ACC_LINE")" -ne 6 ] \
   || { [ "$acc_result" != "PASS" ] && [ "$acc_result" != "NEEDS WORK" ]; } \
   || ! [[ $acc_dispatched =~ $DISPATCHED_RE ]] \
   || ! [[ $acc_spot =~ $SPOT_CHECKED_RE ]] \
   || ! [[ $acc_other =~ $UNVERIFIED_OTHER_RE ]]; then
  emit "$ACC_LN" "$MSG_SUMMARY_FIELDS"
else
  ACC_RESULT="$acc_result"

  if [ "$acc_result" = "PASS" ] && [ "$ACCURACY_NOT_CONFIRMED" -gt 0 ]; then
    emit "$ACC_LN" "$MSG_RESULT_ACCURACY"
  fi

  dispatched="${acc_dispatched#dispatched=}"
  if [ "$dispatched" -ne "$ACCURACY_RECORDS" ]; then
    emit "$ACC_LN" "$MSG_DISPATCHED_COUNT"
  fi

  spot_pair="${acc_spot#spot-checked=}"
  spot_n="${spot_pair%%/*}"
  spot_total="${spot_pair##*/}"
  spot_expected="$spot_total"
  [ "$spot_total" -gt 10 ] && spot_expected=10
  if [ "$spot_n" -ne "$SPOT_CHECK_RECORDS" ] || [ "$spot_n" -ne "$spot_expected" ]; then
    emit "$ACC_LN" "$MSG_SPOT_CHECK_COUNT"
  fi
fi

# RESULT|effectiveness|<PASS or NEEDS WORK>|answered=<n>/5
rest="${EFF_LINE#*|}"; rest="${rest#*|}"
eff_result="${rest%%|*}"; eff_answered="${rest#*|}"

if [ "$(field_count "$EFF_LINE")" -ne 4 ] \
   || { [ "$eff_result" != "PASS" ] && [ "$eff_result" != "NEEDS WORK" ]; } \
   || ! [[ $eff_answered =~ $ANSWERED_RE ]]; then
  emit "$EFF_LN" "$MSG_SUMMARY_FIELDS"
else
  EFF_RESULT="$eff_result"

  if [ "$eff_result" = "PASS" ] && [ "$QUESTIONS_UNANSWERED" -gt 0 ]; then
    emit "$EFF_LN" "$MSG_RESULT_EFFECTIVENESS"
  fi

  answered="${eff_answered#answered=}"
  answered="${answered%%/*}"
  if [ "$answered" -ne "$QUESTIONS_ANSWERED" ]; then
    emit "$EFF_LN" "$MSG_ANSWERED_COUNT"
  fi
fi

# OVERALL|<PASS or NEEDS WORK>
ovr_result="${OVR_LINE#*|}"

if [ "$(field_count "$OVR_LINE")" -ne 2 ] \
   || { [ "$ovr_result" != "PASS" ] && [ "$ovr_result" != "NEEDS WORK" ]; }; then
  emit "$OVR_LN" "$MSG_SUMMARY_FIELDS"
elif [ "$ovr_result" = "PASS" ]; then
  # A RESULT line this run could not read is not evidence against OVERALL:
  # it already carries its own violation.
  if { [ -n "$ACC_RESULT" ] && [ "$ACC_RESULT" != "PASS" ]; } \
     || { [ -n "$EFF_RESULT" ] && [ "$EFF_RESULT" != "PASS" ]; }; then
    emit "$OVR_LN" "$MSG_OVERALL"
  fi
fi

finish
