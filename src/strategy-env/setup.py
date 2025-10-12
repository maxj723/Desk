from setuptools import setup, find_packages

setup(
    name="desk-client",
    version="0.1.0",
    description="Client library for Quant Club Trading Desk",
    packages=find_packages(),
    install_requires=[
        "protobuf>=5.29.2",
        "requests>=2.32.3",
    ],
    python_requires=">=3.8",
)
