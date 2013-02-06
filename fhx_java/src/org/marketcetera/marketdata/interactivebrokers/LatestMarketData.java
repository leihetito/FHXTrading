package org.marketcetera.marketdata.interactivebrokers;

import java.io.File;
import java.math.BigDecimal;
import java.text.SimpleDateFormat;
import java.util.Date;

import org.marketcetera.marketdata.interactivebrokers.IBFeedManager.EventType;

public class LatestMarketData {
	private String symbol;
	
	private MarketDataResponse latestBid=new MarketDataResponse(EventType.Bid);
	private MarketDataResponse latestOffer=new MarketDataResponse(EventType.Offer);
	private MarketDataResponse latestTrade=new MarketDataResponse(EventType.Trade);
	
	public LatestMarketData(String inSymbol) {
		symbol=inSymbol;		
	}
	
	public void setBidPrice(BigDecimal price) {
		latestBid.setPrice(price);
	}
	public void setBidSize(BigDecimal size) {
		latestBid.setSize(size);		
	}
	public void setOfferPrice(BigDecimal price) {
		latestOffer.setPrice(price);
	}
	public void setOfferSize(BigDecimal size) {
		latestOffer.setSize(size);
	}
	public void setTradePrice(BigDecimal price) {
		latestTrade.setPrice(price);		
	}
	public void setTradeSize(BigDecimal size) {
		latestTrade.setSize(size);
	}
	public MarketDataResponse getLatestBid() {
		return latestBid;
	}
	public MarketDataResponse getLatestOffer() {
		return latestOffer;
	}
	public MarketDataResponse getLastestTrade() {
		return latestTrade;
	}
	public void setSymbol(String symbol) {
		this.symbol = symbol.toUpperCase();
	}
	public String getSymbol() {
		return symbol;
	}
	
	public void setTime(Date time) {
		this.latestTime = time;
	}
	public Date getTime() {
		//return this.latestTime;
		return null == this.latestTime ? new Date() : this.latestTime; // for offline testing
	}
	
	public String toString() {
		StringBuilder sb = new StringBuilder();
		
		sb.append(symbol);
		sb.append(",");
		sb.append(latestBid.getPrice().setScale(2));
		sb.append(",");
		sb.append(latestOffer.getPrice().setScale(2));
		sb.append(",");
		sb.append(latestTrade.getPrice().setScale(2));
		sb.append(",");
		sb.append(latestTrade.getSize());
		sb.append(",");
		sb.append(null == this.latestTime ? SDF.format(new Date()) : SDF.format(latestTime));
		sb.append(",");
		sb.append(SDF.format(new Date()));
		sb.append("\n");
		
		
		return sb.toString();
	}
	
	private Date latestTime;
	private static SimpleDateFormat SDF = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");	
}
