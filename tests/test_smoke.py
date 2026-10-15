"""Smoke tests: the toolchain and CI pipeline work before any real code exists."""

import sys


def test_python_version() -> None:
    assert sys.version_info >= (3, 12)
