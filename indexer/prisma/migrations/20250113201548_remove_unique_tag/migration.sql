/*
  Warnings:

  - A unique constraint covering the columns `[txHash]` on the table `TransactionData` will be added. If there are existing duplicate values, this will fail.

*/
-- DropIndex
DROP INDEX "TransactionData_network_key";

-- CreateIndex
CREATE UNIQUE INDEX "TransactionData_txHash_key" ON "TransactionData"("txHash");
