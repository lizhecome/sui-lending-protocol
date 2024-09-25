import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import {
  riskModels,
} from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.updateRiskModel(tx, riskModels.wormholeBtc, coinTypes.wormholeBtc);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);
