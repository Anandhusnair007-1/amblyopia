import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { AlertCircle, CheckCircle2, ShieldCheck, HelpCircle } from "lucide-react";

/**
 * DoctorAIPanel
 * Displays detailed AI screening metrics for clinicians.
 * Only accessible in the Doctor Portal.
 */
export const DoctorAIPanel = ({ aiResult }) => {
  if (!aiResult) return null;

  const { quality, deviation, doctor_review_required, model_version, disclaimer } = aiResult;

  return (
    <Card className="bg-slate-900 border-slate-800 text-white shadow-2xl">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 border-b border-slate-800/50">
        <CardTitle className="text-sm font-medium text-slate-400">
          AI-Assisted Screening Metrics
        </CardTitle>
        <Badge variant="outline" className="bg-blue-500/10 text-blue-400 border-blue-500/20 px-2">
          {model_version}
        </Badge>
      </CardHeader>
      
      <CardContent className="pt-6 space-y-6">
        {/* Quality Metric */}
        <div className="flex items-start justify-between">
          <div className="space-y-1">
            <p className="text-sm font-medium leading-none">Image Quality</p>
            <p className="text-xs text-slate-500 uppercase tracking-wider">{quality?.label}</p>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-sm font-bold">{(quality?.confidence * 100).toFixed(1)}%</span>
            {quality?.is_usable ? 
              <CheckCircle2 className="h-4 w-4 text-emerald-500" /> : 
              <AlertCircle className="h-4 w-4 text-red-500" />
            }
          </div>
        </div>

        {/* Deviation Metric (Doctor Only) */}
        {deviation && (
          <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <p className="text-sm font-medium">Possible Deviation</p>
              {deviation.possible_type === 'uncertain' ? (
                <Badge className="bg-amber-500/20 text-amber-500 border-amber-500/30">
                  <HelpCircle className="w-3 h-3 mr-1" /> AI Uncertain
                </Badge>
              ) : (
                <Badge className="bg-red-500/20 text-red-500 border-red-500/30">
                  {deviation.possible_type} Detected
                </Badge>
              )}
            </div>
            
            <div className="flex items-center justify-between text-xs">
              <span className="text-slate-500">Confidence Score</span>
              <span className="font-mono">{(deviation.confidence * 100).toFixed(1)}%</span>
            </div>

            {deviation.possible_type === 'uncertain' && (
              <p className="text-[10px] text-amber-400/80 leading-relaxed italic">
                Low confidence prediction — Manual clinical review required.
              </p>
            )}
          </div>
        )}

        {/* Verification Status */}
        {doctor_review_required && (
          <div className="flex items-center gap-2 p-3 rounded-lg bg-blue-500/5 border border-blue-500/10 text-[10px] text-blue-400">
            <ShieldCheck className="h-3 w-3" />
            <span>Doctor confirmation required for all AI findings.</span>
          </div>
        )}

        {/* Disclaimer */}
        <p className="text-[9px] text-slate-600 italic leading-tight pt-2 border-t border-slate-800">
          {disclaimer}
        </p>
      </CardContent>
    </Card>
  );
};
