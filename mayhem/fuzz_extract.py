#!/usr/bin/env python3

import atheris
import sys


import fuzz_helpers

with atheris.instrument_imports():
    import parsel

from cssselect import SelectorSyntaxError, ExpressionError


def TestOneInput(data):
    fdp = fuzz_helpers.EnhancedFuzzedDataProvider(data)
    try:
        selector = parsel.Selector(text=fdp.ConsumeRandomString())
        selector.css(fdp.ConsumeRandomString())
        selector.xpath(fdp.ConsumeRandomString())
    except (SelectorSyntaxError, ExpressionError):
        return -1
    except ValueError as e:
        if 'XPath' in str(e) or 'XML' in str(e):
            return -1
        raise

def main():
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
