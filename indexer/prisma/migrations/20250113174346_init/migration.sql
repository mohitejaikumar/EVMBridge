-- CreateEnum
CREATE TYPE "Network" AS ENUM ('SEPOLIA', 'HOLESKY');

-- CreateTable
CREATE TABLE "NetworkStatus" (
    "id" SERIAL NOT NULL,
    "network" "Network" NOT NULL,
    "nonce" INTEGER NOT NULL DEFAULT 0,
    "lastProcessedBlock" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NetworkStatus_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TransactionData" (
    "id" SERIAL NOT NULL,
    "network" "Network" NOT NULL,
    "txHash" TEXT NOT NULL,
    "tokenAddress" TEXT NOT NULL,
    "amount" TEXT NOT NULL,
    "sender" TEXT NOT NULL,
    "nonce" INTEGER NOT NULL,
    "isDone" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TransactionData_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "NetworkStatus_network_key" ON "NetworkStatus"("network");

-- CreateIndex
CREATE UNIQUE INDEX "TransactionData_network_key" ON "TransactionData"("network");
