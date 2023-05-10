## NFT Breeding

## Table of Content

- [Project Description](#project-description)
- [Technologies Used](#technologies-used)
- [Folder Structure](#directory-layout)
- [Install and Run](#install-and-run)

## Project Description 

To develop a template that can be used for developing nft breeding related smart contracts.

## Technologies Used 

- Solidity
- Openzepplein
- Hardhat

## Directory layout

    .
    ├── contracts               # Smart contracts
    ├── scripts                 # Deployment scripts for smart contracts
    ├── test                    # Test files
    └── README.md
## Install and Setup

### Clone

```
git clone https://github.com/svrapidinnovation/NFT_Breeding.git

```
### Installation

Install project's dependencies:

```
cd NFT_Breeding

npm install

```
### Set up .env

create a new .env file by copying it's content from env.example and filling in your secrets

```
cp .env.example .env

```

## Building the projects


### compile

Compile the contracts:

```
npm run compile

```

### Clean

Delete the smart contract artifacts, the coverage reports and the Hardhat cache:

```
npm run clean

```

### Testing

Run the tests:

```
npm run test

```


### Deployment

Deploy the contracts:

```
npm run deploy

```
