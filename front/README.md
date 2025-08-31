# Warren Wallet - DeFi Savings Goals

A Next.js 14 DeFi application for disciplined savings goals on Base Sepolia testnet. Built with TypeScript, Tailwind CSS v4, shadcn/ui, RainbowKit, and wagmi.

## Features

- 🔗 **Wallet Connection**: RainbowKit integration with Base Sepolia network validation
- 💰 **Stablecoin Deposits**: Support for USDC, DAI, and USDT with automatic token approval
- 📤 **Smart Withdrawals**: Early withdrawal penalty calculation and preview
- 📊 **Real-time Dashboard**: Live balance tracking, goal progress, and interactive charts
- 📄 **IPFS Statements**: Monthly statements stored on IPFS for decentralized record-keeping
- 🔒 **Security First**: Comprehensive security headers and CSP protection
- 📱 **Mobile Responsive**: Mobile-first design with dark mode support

## Quick Start

### Prerequisites

- Node.js 18+ and pnpm
- A Web3 wallet (MetaMask, Coinbase Wallet, etc.)
- Base Sepolia testnet ETH for gas fees

### Installation

1. **Clone and install dependencies**
   \`\`\`bash
   git clone <your-repo-url>
   cd warren-wallet
   pnpm install
   \`\`\`

2. **Set up environment variables**
   \`\`\`bash
   cp .env.example .env.local
   \`\`\`

   Edit `.env.local` with your values:
   \`\`\`env
   NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_walletconnect_project_id
   NEXT_PUBLIC_WARREN_WALLET_ADDRESS=0xYourContractAddressOnBaseSepolia
   NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
   NEXT_PUBLIC_BASE_SEPOLIA_RPC=https://sepolia.base.org
   \`\`\`

3. **Start development server**
   \`\`\`bash
   pnpm dev
   \`\`\`

   Open [http://localhost:3000](http://localhost:3000) in your browser.

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID` | WalletConnect project ID from [cloud.walletconnect.com](https://cloud.walletconnect.com) | Yes | `demo-project-id` |
| `NEXT_PUBLIC_WARREN_WALLET_ADDRESS` | Warren Wallet contract address on Base Sepolia | Yes | `0x0000...` |
| `NEXT_PUBLIC_IPFS_GATEWAY` | IPFS gateway URL for statement access | No | `https://ipfs.io/ipfs/` |
| `NEXT_PUBLIC_BASE_SEPOLIA_RPC` | Custom RPC endpoint for Base Sepolia | No | Public RPC |

## Contract Integration

### Setting Up Your Contract

1. **Deploy the Warren Wallet contract** to Base Sepolia testnet
2. **Update the contract address** in your `.env.local` file
3. **Verify the ABI** matches your contract in `lib/abis/warrenWallet.json`

### Required Contract Functions

The app expects these functions in your smart contract:

```solidity
// Deposit stablecoins to a savings goal
function deposit(address asset, uint256 amount, uint32 goalId) external;

// Withdraw with potential early withdrawal penalty
function withdraw(uint32 goalId, uint256 amount) external;

// Get user's vault balance
function vaultBalanceOf(address user) external view returns (uint256);

// Get user's goal details
function getGoalDetails(address user) external view returns (
    uint32 goalId,
    uint256 targetAmount,
    uint256 currentAmount,
    uint256 deadline,
    bool isActive
);
