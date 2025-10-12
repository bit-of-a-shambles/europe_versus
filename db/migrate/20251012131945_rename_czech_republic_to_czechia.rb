class RenameCzechRepublicToCzechia < ActiveRecord::Migration[8.0]
  def up
    # Update all metrics with country 'czech_republic' to 'czechia'
    Metric.where(country: 'czech_republic').update_all(country: 'czechia')
    
    puts "✅ Updated #{Metric.where(country: 'czechia').count} records from 'czech_republic' to 'czechia'"
  end
  
  def down
    # Rollback: change 'czechia' back to 'czech_republic'
    Metric.where(country: 'czechia').update_all(country: 'czech_republic')
    
    puts "⏪ Rolled back records from 'czechia' to 'czech_republic'"
  end
end
