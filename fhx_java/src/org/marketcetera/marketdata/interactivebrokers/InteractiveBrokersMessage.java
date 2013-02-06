package org.marketcetera.marketdata.interactivebrokers;

import java.util.ArrayList;
import java.util.List;

import org.marketcetera.trade.MSymbol;

import com.ib.client.Contract;

public class InteractiveBrokersMessage {
	public InteractiveBrokersMessage(){}
	private String requestId;
	private List<MSymbol> symbolList=new ArrayList<MSymbol>();
	
	private Contract getContractFromSymbol(String symbol) {
		Contract contract=new Contract();
		contract.m_secType="STK";
		contract.m_exchange="SMART";
		contract.m_currency="USD";
		contract.m_symbol=symbol;
		return contract;
	}

	/*`twsCurrency` <-
	function (symbol,currency="USD",exch="IDEALPRO", primary="", strike = "0.0", 
	    right = "", local = "", multiplier = "", include_expired = "0", conId=0) 
	{
	    twsContract(conId,symbol, "CASH", exch, primary, expiry = "", strike, 
	        currency, right, local, multiplier, NULL, NULL, include_expired)
	}*/
	private Contract getFXContractFromSymbol(String symbol) {
		Contract contract=new Contract();
		contract.m_secType="CASH";
		contract.m_exchange="IDEALPRO";
		contract.m_currency="USD";
		contract.m_symbol=symbol;
		return contract;
	}
	
	public List<Contract> getContracts() {
		List<Contract> contracts=new ArrayList<Contract>();
		for (MSymbol symbol : symbolList) {

			// gfeng: add support for FX -- for testing
			if (symbol.getFullSymbol().equals("EUR")
					|| symbol.getFullSymbol().equals("JPY")
					|| symbol.getFullSymbol().equals("GBP"))
				contracts.add(getFXContractFromSymbol(symbol.getFullSymbol()));
			else 
				contracts.add(getContractFromSymbol(symbol.getFullSymbol()));
		}
		return contracts;
	}

	public void setSymbolList(List<MSymbol> inSymbolList) {	
		this.symbolList=inSymbolList;
	}	
	public void setRequestId(String inRequestId) {
		this.requestId = inRequestId;
	}
	public String getRequestId() {
		return requestId;
	}

}
